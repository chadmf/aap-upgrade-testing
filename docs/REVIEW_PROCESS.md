# Code Review Process

This document describes the review process for contributions to the AAP Upgrade Testing project.

## Overview

All changes to the `main` branch require review. The review process ensures code quality, security, and architectural soundness before merging.

## When Reviews Are Required

### All Pull Requests

**Every PR to `main` requires:**
- ✅ Automated checks (CI) pass
- ✅ Code review by at least 1 maintainer
- ✅ All conversations resolved

### Architectural Review

**Required for:**
- New task files or major modifications to existing ones
- Changes to error handling patterns
- Modularity or extensibility changes
- Report format or data structure changes
- New role variables or configuration options
- Integration with external systems

**Triggered by:**
- CODEOWNERS assignment (automatic for `/roles/` changes)
- Maintainer request
- PR author self-identifies need

### Security Review

**Required for:**
- Secret or credential handling changes
- Authentication or authorization changes
- Input validation changes
- Debug or logging output changes
- RBAC requirement changes
- Changes to `check_database.yml`
- Changes to GitHub Actions workflows

**Triggered by:**
- CODEOWNERS assignment (automatic for security-sensitive files)
- Maintainer request
- Security label applied to PR

## Review Process Flow

```
┌─────────────────────┐
│ Developer creates PR│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Automated checks    │
│ (CI/CD)             │
└──────────┬──────────┘
           │ (pass)
           ▼
┌─────────────────────┐
│ Code review by      │
│ maintainer          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Architecture review │◄─── If needed
│ (if required)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Security review     │◄─── If needed
│ (if required)       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ All reviews         │
│ approved            │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Merge to main       │
└─────────────────────┘
```

## Reviewer Responsibilities

### Code Reviewers (Maintainers)

**Focus Areas:**
- ✅ Logic correctness
- ✅ Ansible best practices
- ✅ Code style and consistency
- ✅ Documentation completeness
- ✅ Test coverage (when applicable)

**Use Checklist:**
- Code follows existing patterns
- Task names are descriptive
- Variables properly documented in defaults/main.yml
- README updated if behavior changes
- No hardcoded values (use defaults)
- Error handling appropriate
- `changed_when` and `failed_when` used correctly

**Review Tools:**
- Read the code in GitHub
- Clone PR branch for local testing (optional)
- Run linters locally if needed
- Check automated CI results

### Architecture Reviewers

**Focus Areas:**
- ✅ System design and structure
- ✅ Modularity and extensibility
- ✅ Error handling patterns
- ✅ Code reusability
- ✅ Long-term maintainability

**Use Checklist:**
See `.github/ARCHITECTURE_REVIEW.md` for detailed checklist

**Expected Turnaround:** 3 business days

### Security Reviewers

**Focus Areas:**
- ✅ Credential and secret handling
- ✅ Input validation
- ✅ Data exposure (logs, reports, output)
- ✅ Authentication and authorization
- ✅ Network security
- ✅ Dependency security

**Use Checklist:**
See `.github/SECURITY_REVIEW.md` for detailed checklist

**Expected Turnaround:**
- Critical security fixes: Same day
- Other security reviews: 3 business days

## Review SLAs

| Review Type | Standard SLA | Critical Security |
|-------------|--------------|-------------------|
| Code Review | 2 business days | Same day |
| Architecture Review | 3 business days | N/A |
| Security Review | 3 business days | Same day |

## Review Decision Types

### 1. Approved ✅

- No issues found
- Or minor suggestions that don't block merge
- PR can be merged

### 2. Approved with Changes ✔️

- Minor issues that should be fixed
- Not blocking merge
- Can be addressed in current PR or follow-up

### 3. Request Changes ⚠️

- Significant issues that must be addressed
- Blocks merge until fixed
- Reviewer will re-review after changes

### 4. Blocked 🔴

- Critical issues (usually security)
- Merge absolutely blocked
- May require design discussion or major rework

## What Reviewers Look For

### Code Quality

**Good:**
```yaml
- name: Preflight | Validate kubeconfig path
  ansible.builtin.assert:
    that:
      - aap_kubeconfig_path is match('^[a-zA-Z0-9/_.-]+$')
    fail_msg: "Invalid kubeconfig path: {{ aap_kubeconfig_path }}"
  when: aap_kubeconfig_path is defined
```

**Needs Improvement:**
```yaml
- name: Check path
  shell: test -f {{ aap_kubeconfig_path }}  # No validation, shell injection risk
```

### Ansible Best Practices

**Good:**
```yaml
- name: Database | Extract host from secret
  ansible.builtin.set_fact:
    db_host: "{{ secret.data.host | b64decode }}"
  no_log: true  # Secrets never logged
  when: secret.data.host is defined
```

**Needs Improvement:**
```yaml
- name: Get host
  set_fact:
    db_host: "{{ secret.data.host | b64decode }}"
  # Missing: no_log, task name prefix, when condition
```

### Documentation

**Good:**
```yaml
# roles/aap_pre_upgrade_check/defaults/main.yml

# CPU usage percentage threshold for warnings (0-100)
# Triggers warning in report if node CPU exceeds this value
aap_node_cpu_warning_threshold: 70
```

**Needs Improvement:**
```yaml
aap_node_cpu_warning_threshold: 70  # No description
```

## Providing Feedback

### Constructive Comments

**Good:**
```
The credential extraction on line 42 needs `no_log: true` to prevent 
passwords from appearing in Ansible output. See SECURITY_REVIEW.md 
section 2 for examples.
```

**Not Helpful:**
```
Fix security issue
```

### Asking Questions

**Good:**
```
Why did you choose `failed_when: false` here instead of handling the 
error with a conditional? It would be more explicit to check 
`db_secret_info.resources | length > 0` first.
```

**Not Helpful:**
```
This is wrong
```

### Suggesting Improvements

**Good:**
```
Consider extracting this Jinja2 template to a filter plugin for better 
testability and reusability. Example: `{{ data | parse_cluster_info }}`
```

**Not Helpful:**
```
This should be a filter plugin
```

## Responding to Review Comments

### As PR Author

1. **Read all comments thoroughly**
2. **Ask clarifying questions** if you don't understand feedback
3. **Address each comment:**
   - Make the requested change, OR
   - Explain why you disagree (respectfully)
   - Mark conversation as resolved when done
4. **Push new commits** with fixes (don't force-push during review)
5. **Request re-review** when all comments addressed

### Disagreements

If you disagree with review feedback:

1. **Explain your reasoning** (politely)
2. **Provide examples** or references supporting your approach
3. **Propose alternatives** if you see a different solution
4. **Escalate if needed:**
   - Tag additional reviewers for their input
   - Request architecture/security review if it's a design question

## Automated Checks (CI/CD)

PRs must pass all automated checks before review:

### Required Checks

- ✅ `lint-yaml` - YAML formatting
- ✅ `lint-ansible` - Ansible best practices (production profile)
- ✅ `lint-markdown` - Documentation formatting
- ✅ `security-scan` - Secret detection (Gitleaks)
- ✅ `validate-role` - Role structure validation
- ✅ `syntax-check` - Ansible playbook syntax

### Check Failures

If a check fails:

1. **Review the error output** in GitHub Actions
2. **Fix locally:**
   ```bash
   pre-commit run --all-files  # Run all checks
   ```
3. **Push the fix**
4. **Checks run automatically** on new commit

## Merge Process

After all approvals:

### 1. Final Checks

- [ ] All required reviews approved
- [ ] All conversations resolved
- [ ] All CI checks passing
- [ ] Branch up to date with main

### 2. Merge Method

**Preferred:** Squash and merge
- Keeps main history clean
- One commit per feature/fix
- Preserves PR discussion

**Alternative:** Rebase and merge
- For PRs with clean, meaningful commit history
- Each commit should be atomic

**Never:** Merge commit
- Creates noise in history
- Makes bisecting harder

### 3. After Merge

- PR branch auto-deleted (GitHub setting)
- CI runs on main to validate
- Changes are immediately available

## Review Escalation

### When to Escalate

- Disagreement between reviewers
- Unsure about architectural decision
- Security concern needs broader input
- Breaking change proposal

### How to Escalate

1. **Comment in PR:** Summarize the issue and tag relevant people
2. **Create Discussion:** For broader architectural questions
3. **Schedule Meeting:** For complex decisions requiring real-time discussion

## Tips for Faster Reviews

### For PR Authors

- ✅ Keep PRs small and focused
- ✅ Write clear PR description
- ✅ Self-review before requesting review
- ✅ Ensure CI passes before requesting review
- ✅ Respond to feedback promptly

### For Reviewers

- ✅ Review within SLA timeframes
- ✅ Provide actionable feedback
- ✅ Distinguish blocking vs. non-blocking comments
- ✅ Approve promptly if no issues found

## Review Metrics

We track:
- Time to first review
- Time to approval
- Number of review rounds
- Review rejection rate

Goals:
- 80% of PRs reviewed within SLA
- Average 1.5 review rounds per PR
- <10% rejection rate

## Examples

### Example 1: Simple Bug Fix

```
PR: Fix typo in database namespace default
├─ Automated checks: ✅ Pass
├─ Code review: ✅ Approved (typo fix, no logic change)
└─ Merge: ✅ Squash and merge
```

### Example 2: New Feature

```
PR: Add etcd health check task
├─ Automated checks: ✅ Pass
├─ Code review: ⚠️ Request changes (missing documentation)
├─ Author updates: Adds docs, responds to comments
├─ Code review: ✅ Approved
├─ Architecture review: ✅ Approved (follows patterns)
└─ Merge: ✅ Squash and merge
```

### Example 3: Security Fix

```
PR: Add no_log to credential extraction
├─ Automated checks: ✅ Pass
├─ Security review: ✅ Approved (critical fix)
├─ Code review: ✅ Approved (fast-tracked)
└─ Merge: ✅ Squash and merge (same day)
```

## Questions?

See:
- `CONTRIBUTING.md` - How to contribute
- `docs/REVIEWER_GUIDE.md` - Detailed reviewer instructions
- `.github/ARCHITECTURE_REVIEW.md` - Architecture review checklist
- `.github/SECURITY_REVIEW.md` - Security review checklist

Or ask in:
- PR comments
- GitHub Discussions
- Team Slack channel
