# ADR-0001: Role-Based Health Check Architecture

**Date:** 2026-05-29  
**Status:** Accepted  
**Author:** Chad Ferman

## Context

We need an automated way to validate AAP deployments on OpenShift before performing upgrades. Manual validation is time-consuming, error-prone, and doesn't scale across multiple clusters. We need a solution that:

- Checks node health, operator status, AAP instance health, and database backend
- Generates comprehensive reports for upgrade planning
- Is reusable across different cluster configurations
- Can be integrated into CI/CD pipelines
- Follows Ansible and Red Hat best practices

## Decision

We will implement health checks as an **Ansible role** (`aap_pre_upgrade_check`) with the following architecture:

### Core Design Principles

1. **Role-Based Structure**
   - Single role: `aap_pre_upgrade_check`
   - Task files organized by component (nodes, operators, instances, database)
   - Playbooks as entry points for different clusters

2. **Fact-Based Data Aggregation**
   - All check results stored in structured fact: `aap_check_results`
   - Fact includes issues (critical), warnings (advisory), and detailed component status
   - Report generation consumes fact data via Jinja2 template

3. **Configurable Behavior**
   - Thresholds in `defaults/main.yml` (CPU, memory warnings)
   - Failure behavior controlled by boolean flags
   - Optional components via conditional includes

4. **Tag-Based Execution**
   - Tags enable selective execution: `--tags nodes,operators`
   - Parallel workflow possible (run checks independently)

5. **External Tool Integration**
   - Uses `kubernetes.core` collection for Kubernetes API
   - Falls back to `kubectl` CLI for metrics (when available)
   - Graceful degradation if metrics-server unavailable

### Architecture Overview

```
Entry Playbook
    ↓
roles/aap_pre_upgrade_check/
    ├── tasks/
    │   ├── main.yml           (orchestrator)
    │   ├── preflight.yml       (validate prerequisites)
    │   ├── check_nodes.yml     (node health)
    │   ├── check_operators.yml (AAP operators)
    │   ├── check_aap_instance.yml (AAP CR)
    │   ├── check_database.yml  (PostgreSQL)
    │   └── generate_report.yml (markdown output)
    ├── templates/
    │   └── pre_upgrade_report.md.j2
    ├── defaults/main.yml
    └── meta/main.yml
    ↓
Output: Console + Markdown Report
```

## Consequences

### Positive

- ✅ **Reusability:** Role can be consumed by any playbook, easily integrated
- ✅ **Consistency:** Same checks run identically across all clusters
- ✅ **Maintainability:** Modular task files, single responsibility per file
- ✅ **Flexibility:** Tag-based execution, configurable thresholds
- ✅ **Automation-Friendly:** Can be integrated into CI/CD, scheduled jobs
- ✅ **Documentation:** Ansible's self-documenting nature + README

### Negative

- ⚠️ **Complexity:** Multiple task files, Jinja2 templates can be complex
- ⚠️ **Dependencies:** Requires `kubernetes.core` collection
- ⚠️ **Testing:** No built-in testing framework (Molecule not implemented)
- ⚠️ **Error Handling:** Some failures suppressed (`failed_when: false`) for graceful degradation

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Large Jinja2 templates hard to maintain | Consider filter plugins for complex logic |
| No test coverage | Add Molecule tests in future iteration |
| Dependency on kubernetes.core | Pin version in requirements.yml |
| Report format inflexible | Template can be extended, consider JSON output |

## Alternatives Considered

### 1. Script-Based Approach (Bash/Python)

**Pros:**
- Simpler for some operations
- No Ansible dependency

**Cons:**
- Less idempotent
- Harder to reuse and configure
- No standard reporting format
- Doesn't integrate with existing Ansible workflows

**Decision:** Rejected - doesn't fit Red Hat ecosystem

### 2. Operator-Based Health Checker

**Pros:**
- Native Kubernetes integration
- Real-time monitoring

**Cons:**
- More complex to develop and deploy
- Requires cluster deployment permissions
- Overhead for one-time pre-upgrade checks

**Decision:** Rejected - overengineered for the use case

### 3. Ansible Collection (Multiple Roles)

**Pros:**
- More modular
- Each check type as separate role

**Cons:**
- Overhead of multiple roles
- More complex dependency management
- Harder to maintain consistent state

**Decision:** Rejected - single role simpler for this scope

## Implementation Notes

### Extension Points

Future enhancements can add:
- New check types (add task file + include in main.yml)
- Alternative report formats (JSON, YAML)
- Custom filter plugins for complex transformations
- Molecule tests for validation

### Known Technical Debt

1. Large Jinja2 templates in `set_fact` tasks
   - `check_database.yml` lines 65-116
   - `check_nodes.yml` parsing logic
   - **Future:** Extract to filter plugins

2. No automated testing
   - **Future:** Add Molecule test scenarios

3. Error handling inconsistency
   - Some tasks use `failed_when: false`, others use conditionals
   - **Future:** Standardize error handling pattern

## References

- Ansible Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
- kubernetes.core Collection: https://docs.ansible.com/ansible/latest/collections/kubernetes/core/
- Red Hat CoP Practices: https://redhat-cop.github.io/automation-good-practices/

## Review History

- 2026-05-29: Initial ADR (Chad Ferman)
