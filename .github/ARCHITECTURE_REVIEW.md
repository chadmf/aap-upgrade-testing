# Architecture Review Checklist

This document guides software architects in reviewing code changes for architectural soundness, maintainability, and adherence to best practices.

## Review Scope

Architectural review is required for:

- New task files or major modifications
- Changes to error handling patterns
- Modularity and extensibility changes
- Report format or data structure changes
- New role variables or configuration options
- Integration with external systems

## Review Categories

### 1. Error Handling Patterns

**Objective:** Ensure consistent, predictable, and maintainable error handling

**Review Points:**

- [ ] Error handling is consistent across all task files
- [ ] Use of `failed_when: false` is justified and documented
  - Each occurrence should have a comment explaining why
  - Alternative handling must be present (conditional checks, warnings)
- [ ] Error messages are actionable and include context
- [ ] Graceful degradation implemented for optional features
  - Example: Metrics unavailable → continue with "N/A" values
- [ ] Failed tasks don't leave system in inconsistent state
- [ ] Retry logic implemented where appropriate (network calls, API requests)

**Known Hotspots:**
- `roles/aap_pre_upgrade_check/tasks/check_database.yml` - Multiple `failed_when: false`
- `roles/aap_pre_upgrade_check/tasks/check_operators.yml` - CSV query failures

**Decision Matrix:**
| Pattern | Acceptable | Requires Change |
|---------|-----------|-----------------|
| `failed_when: false` with documented reason and conditional handling | ✓ | |
| `failed_when: false` without justification | | ✗ |
| Inconsistent error handling across similar tasks | | ✗ |
| Silent failures without logging | | ✗ |

---

### 2. Modularity & Extensibility

**Objective:** Code is organized for reusability and future enhancements

**Review Points:**

- [ ] Role structure follows Ansible best practices
  - tasks/, defaults/, vars/, templates/, handlers/, meta/
- [ ] Task files have single, well-defined responsibilities
- [ ] New check types can be added without modifying existing code
- [ ] Report format can be extended for new data types
- [ ] Role can be consumed by other playbooks/roles
- [ ] Tags enable granular execution (`--tags nodes,operators`)
- [ ] Extension points are documented

**Extensibility Patterns:**

Good:
```yaml
# New checks can be added as separate task files
- name: Check custom resources
  include_tasks: check_custom_resource.yml
  when: enable_custom_checks | default(false)
```

Needs Improvement:
```yaml
# Hardcoded check list that requires code changes
- name: Run all checks
  include_tasks: "{{ item }}"
  loop:
    - check_nodes.yml
    - check_operators.yml
    # Adding new checks requires editing this file
```

**Decision Matrix:**
| Pattern | Acceptable | Requires Discussion |
|---------|-----------|---------------------|
| New checks require new task files only | ✓ | |
| New checks require editing multiple existing files | | ⚠️ |
| Hardcoded assumptions about cluster layout | | ⚠️ |

---

### 3. Code Reusability

**Objective:** Reduce duplication and improve maintainability

**Review Points:**

- [ ] Large Jinja2 templates extracted to filter plugins or vars files
- [ ] Common patterns abstracted to reusable components
- [ ] Similar logic across tasks consolidated
- [ ] Helper functions created for complex transformations

**Known Opportunities:**
- `check_database.yml` lines 65-116 - Large Jinja2 template in `set_fact`
- `check_nodes.yml` - Similar complex template patterns
- Consider: Custom filter plugins for data transformation

**Refactoring Suggestions:**

Before:
```yaml
- name: Analyze results
  set_fact:
    parsed_data: |
      {%- set result = {} -%}
      {%- for item in data -%}
        # 50 lines of Jinja2 logic
      {%- endfor -%}
      {{ result }}
```

After (with filter plugin):
```yaml
- name: Analyze results
  set_fact:
    parsed_data: "{{ data | custom_filter }}"
```

---

### 4. Dependency Management

**Objective:** Dependencies are explicit, versioned, and documented

**Review Points:**

- [ ] `kubernetes.core` collection version pinned in requirements.yml
- [ ] Role metadata (`meta/main.yml`) lists all dependencies
- [ ] Minimum Ansible version documented and enforced
- [ ] Collection requirements file exists and is up-to-date
- [ ] No undocumented system dependencies (packages, CLI tools)

**Required Files:**
- `requirements.yml` - Ansible collection dependencies with versions
- `meta/main.yml` - Role dependencies and requirements
- README - Installation prerequisites and steps

---

### 5. Configuration Management

**Objective:** Configuration is flexible, well-documented, and follows conventions

**Review Points:**

- [ ] All configurable values in `defaults/main.yml`
- [ ] No hardcoded paths, URLs, or values in task files
- [ ] Sensible defaults that work for most users
- [ ] Variable names follow convention: `<role>_<purpose>`
  - Example: `aap_node_cpu_warning_threshold`
- [ ] Boolean flags for feature toggles
- [ ] Documentation for each variable (type, purpose, default, example)

**Anti-patterns:**
```yaml
# BAD - hardcoded in task file
- name: Check namespace
  k8s_info:
    namespace: ansible-automation-platform  # Hardcoded

# GOOD - use variable
- name: Check namespace
  k8s_info:
    namespace: "{{ aap_namespace }}"  # From defaults/main.yml
```

---

### 6. Data Flow & State Management

**Objective:** Data transformations are clear, facts are scoped appropriately

**Review Points:**

- [ ] `aap_check_results` fact structure is documented
- [ ] Fact scope is appropriate (task, play, host)
- [ ] Data transformations are testable
- [ ] Intermediate facts cleaned up when no longer needed
- [ ] Large data sets handled efficiently (avoid memory issues)

**Fact Structure Documentation:**
```yaml
aap_check_results:
  timestamp: "ISO 8601 timestamp"
  cluster_version: "Kubernetes version"
  nodes: {}        # Dictionary of node data
  operators: {}    # Operator status
  aap_instance: {} # AAP CR status
  database: {}     # Database info
  issues: []       # Critical problems
  warnings: []     # Non-critical warnings
```

---

### 7. Report Generation

**Objective:** Reports are structured, extensible, and maintainable

**Review Points:**

- [ ] Template organization is logical and scannable
- [ ] Report sections can be added without breaking existing content
- [ ] Report format options (JSON, YAML, markdown)
- [ ] Output directory creation handles permissions correctly
- [ ] Reports include metadata (timestamp, version, cluster)
- [ ] Conditional sections (only show if data exists)

**Template Best Practices:**
- Use consistent heading hierarchy (##, ###)
- Include table of contents for long reports
- Use tables for structured data
- Include visual indicators (✓, ✗, ⚠️) sparingly

---

### 8. Testing & Validation

**Objective:** Code is testable and has appropriate test coverage

**Review Points:**

- [ ] Example playbooks demonstrate usage
- [ ] Syntax checking passes (`ansible-playbook --syntax-check`)
- [ ] Linting passes (ansible-lint production profile)
- [ ] Test coverage appropriate for complexity
  - Unit tests for filter plugins
  - Integration tests for end-to-end workflows
- [ ] Mock data available for testing without real cluster

**Testing Gaps (Current):**
- No Molecule tests
- No integration test suite
- No mock cluster data for offline testing

---

## Architectural Decision Records (ADRs)

For significant architectural changes, create an ADR in `docs/adr/`:

```markdown
# ADR-XXXX: Title

Date: YYYY-MM-DD
Status: Proposed | Accepted | Deprecated

## Context
[Problem description]

## Decision
[What we decided to do]

## Consequences
[Trade-offs and impacts]

## Alternatives Considered
[Other options we evaluated]
```

---

## Review Decision Matrix

| Finding Type | Action | Timeline |
|--------------|--------|----------|
| **Critical Architectural Flaw** | Block merge, require redesign | Immediate |
| **Significant Concern** | Request changes, discussion required | Before merge |
| **Improvement Opportunity** | Suggest enhancement, not blocking | Document for future |
| **Best Practice Recommendation** | Comment for awareness | Optional |

---

## Approval Checklist

Before approving:

- [ ] All critical and significant concerns addressed
- [ ] Patterns are consistent with existing codebase
- [ ] Code is maintainable by team
- [ ] Documentation updated
- [ ] ADR created if needed
- [ ] Future technical debt documented

---

## Review Comments Template

```markdown
## Architecture Review - [Date]

### Summary
[Overall assessment: Approved / Approved with changes / Changes required]

### Findings

#### Critical Issues
- None / [List with line references]

#### Concerns
- [List items for discussion]

#### Suggestions
- [Improvement opportunities]

### Decision
- [ ] Approved
- [ ] Approved with minor changes
- [ ] Changes required before merge

**Reviewer:** [Name]
**Date:** [YYYY-MM-DD]
```
