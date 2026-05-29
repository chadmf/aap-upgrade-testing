# Reviewer Guide

Quick reference for code reviewers of the AAP Upgrade Testing project.

## Quick Links

- **Architecture Review Checklist:** `.github/ARCHITECTURE_REVIEW.md`
- **Security Review Checklist:** `.github/SECURITY_REVIEW.md`
- **Review Process:** `docs/REVIEW_PROCESS.md`
- **Contributing Guide:** `CONTRIBUTING.md`

## Before You Start

### Setup Your Environment

```bash
# Clone the repository (if not already done)
git clone git@github.com:<org>/aap-upgrade-testing.git
cd aap-upgrade-testing

# Install development tools
pip install pre-commit ansible-core ansible-lint yamllint

# Install collections
ansible-galaxy collection install -r requirements.yml

# Install pre-commit hooks (optional but recommended)
pre-commit install
```

### Review Assignment

You'll be assigned to PRs based on:

- **CODEOWNERS** file (automatic assignment)
- **Manual assignment** by PR author or maintainer
- **Your expertise** (architecture, security, specific area)

## Review Workflow

### 1. Initial Triage (2 minutes)

**Check:**
- [ ] PR description is clear
- [ ] CI checks are passing (or running)
- [ ] PR size is reasonable (<500 lines changed)
- [ ] Branch is up to date with main

**If Not Ready:**
- Comment: "Please ensure CI passes and branch is up to date with main before review."
- Set status: "Changes requested"

### 2. Understand the Change (5-10 minutes)

**Read:**
- PR description and linked issues
- File diffs in GitHub
- Related code context

**Ask Yourself:**
- What problem does this solve?
- How does it solve it?
- Does the solution make sense?

### 3. Review Code (15-30 minutes)

**Use appropriate checklist:**
- **Code review:** General quality, Ansible best practices
- **Architecture review:** `.github/ARCHITECTURE_REVIEW.md`
- **Security review:** `.github/SECURITY_REVIEW.md`

**Test Locally (Optional but Recommended):**

```bash
# Check out the PR branch
gh pr checkout <PR-number>

# Or manually:
git fetch origin pull/<PR-number>/head:pr-<PR-number>
git checkout pr-<PR-number>

# Run linters
pre-commit run --all-files

# Syntax check
ansible-playbook --syntax-check playbooks/*.yml

# Test against a cluster (if applicable)
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/test-config \
  --check  # Dry run
```

### 4. Provide Feedback (10-15 minutes)

**Comment Types:**

- **Blocking:** Must be fixed before merge

  ```text
  ❌ This credential extraction needs `no_log: true` to prevent passwords
  from appearing in output. This is a security requirement.
  ```

- **Non-blocking:** Suggestions for improvement

  ```text
  💡 Consider using a filter plugin here for better testability. Not blocking,
  but would improve maintainability.
  ```

- **Question:** Seeking clarification

  ```text
  ❓ Why did you choose `failed_when: false` here instead of a conditional?
  Could you explain the reasoning?
  ```

- **Praise:** Acknowledge good work

  ```text
  ✅ Excellent error handling here. The fail message is very actionable.
  ```

### 5. Make Decision (1 minute)

**Approve:** No issues or only minor suggestions

```text
✅ Looks good! Minor suggestion about the filter plugin but not blocking.
```

**Request Changes:** Issues that must be fixed

```text
⚠️ Please address the security issue on line 42 before merging. See my
comment for details.
```

**Comment:** Waiting for more information

```text
❓ I've left a few questions. Please clarify and I'll continue the review.
```

## What to Look For

### Code Quality Checklist

- [ ] **Task names** are descriptive and follow prefix convention
  - Good: `Preflight | Validate kubeconfig path`
  - Bad: `Check path`

- [ ] **Variables** properly documented in `defaults/main.yml`
  ```yaml
  # Description of what this does and valid values
  variable_name: default_value
  ```

- [ ] **No hardcoded values** in task files
  - Use variables from `defaults/main.yml`

- [ ] **Error handling** is appropriate
  - `changed_when` for idempotency
  - `failed_when` with justification
  - Meaningful error messages

- [ ] **Documentation** updated
  - README if behavior changes
  - Role docs if variables added
  - Comments for complex logic

### Ansible Best Practices

- [ ] **Idempotency:** Can be run multiple times safely
- [ ] **Module usage:** Use Ansible modules over shell/command when possible
- [ ] **YAML formatting:** Consistent style, proper indentation
- [ ] **Tags:** Appropriate tags for selective execution
- [ ] **Conditionals:** `when` clauses are clear and correct

### Security Checklist

- [ ] **No secrets in output**
  - `no_log: true` on tasks handling secrets
  - Debug output sanitized

- [ ] **Input validation**
  - Paths validated before use
  - User inputs checked

- [ ] **Credential handling**
  - Secrets from vaults or Kubernetes
  - Never hardcoded

### Common Issues

#### Issue: Missing `no_log` on Secret Handling

**Bad:**

```yaml
- name: Extract password
  set_fact:
    db_password: "{{ secret | b64decode }}"
```

**Fix:**

```yaml
- name: Extract password
  set_fact:
    db_password: "{{ secret | b64decode }}"
  no_log: true  # Prevent password in output
```

**Comment:**

```text
Please add `no_log: true` to this task. Without it, the password will
appear in Ansible output. See SECURITY_REVIEW.md section 2.
```

#### Issue: Hardcoded Value

**Bad:**

```yaml
- name: Check AAP namespace
  k8s_info:
    namespace: ansible-automation-platform  # Hardcoded
```

**Fix:**

```yaml
- name: Check AAP namespace
  k8s_info:
    namespace: "{{ aap_namespace }}"
```

**Comment:**

```text
Please use the `aap_namespace` variable instead of hardcoding. This makes
the role reusable across different installations.
```

#### Issue: Unclear Task Name

**Bad:**

```yaml
- name: Check things
  k8s_info:
    kind: Pod
```

**Fix:**

```yaml
- name: Operators | Get operator pods
  k8s_info:
    kind: Pod
    namespace: "{{ aap_namespace }}"
    label_selectors:
      - app=operator
```

**Comment:**

```text
Task name should be more specific. Suggest: "Operators | Get operator pods"
Also, consider adding a label selector to only get operator pods.
```

## Testing PRs

### Quick Test (No Cluster)

```bash
# Check out PR
gh pr checkout <PR-number>

# Run linters
yamllint -c .yamllint.yml .
ansible-lint --profile production

# Syntax check
ansible-playbook --syntax-check playbooks/*.yml
```

### Full Test (With Cluster Access)

```bash
# Run against test cluster
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/test-config \
  -e aap_namespace=test-aap \
  --check  # Dry run first

# Review the output
# Check for errors, warnings, unexpected behavior

# Run for real (generates report)
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/test-config \
  -e aap_namespace=test-aap

# Review the generated report
cat reports/pre-upgrade-check-*.md
```

## Providing Feedback

### Comment Guidelines

**Be specific:**

- ❌ "Fix this"
- ✅ "Add `no_log: true` on line 42 to prevent passwords in output"

**Be constructive:**

- ❌ "This is wrong"
- ✅ "This approach works, but consider using X instead because Y"

**Provide context:**

- ❌ "Use a filter plugin"
- ✅ "Consider using a filter plugin here for better testability. Large Jinja2 templates are harder to test
  and reuse. See `docs/adr/` for examples."

**Distinguish blocking vs. non-blocking:**

- Blocking: "Please fix before merge"
- Non-blocking: "Suggestion for improvement (not blocking)"

### Review Comment Template

```markdown
## Review Comments

### Blocking Issues

1. **line 42:** Add `no_log: true` to prevent credential exposure
2. **line 87:** Input validation needed for `kubeconfig_path`

### Suggestions

1. **line 123:** Consider extracting this Jinja2 template to a filter plugin
2. **documentation:** Add example for the new variable in README

### Questions

1. **line 56:** Why `failed_when: false` instead of a conditional check?

### Praise

- Excellent error handling throughout
- Documentation is very clear

---

**Decision:** Request Changes (blocking issues must be addressed)
```

## Escalation

### When to Involve Architecture Review

- Significant design changes
- New task file structure
- Changes to error handling patterns
- Unsure about modularity/extensibility

**How:** Tag `@<org>/software-architects` in a comment

### When to Involve Security Review

- Credential or secret handling
- Authentication/authorization changes
- Potential data exposure
- Unsure about security implications

**How:** Tag `@<org>/security-architects` in a comment

## Time Management

**Target times:**

- Small PRs (less than 50 lines): 15 minutes
- Medium PRs (50-200 lines): 30 minutes
- Large PRs (200-500 lines): 60 minutes
- Huge PRs (more than 500 lines): Request split into smaller PRs

**SLA:**

- First review within 2 business days
- Re-review within 1 business day

**If you cannot meet SLA:**

- Comment in PR: "I will need until [date] to review this thoroughly"
- Or reassign to another reviewer

## Common Reviewer Mistakes

### Mistake: Nitpicking Style

**Do not:**

```text
Change variable name from `aap_cpu_threshold` to `aap_cpu_warning_threshold`
```

**Unless:** The name is genuinely confusing or inconsistent with existing patterns

**Remember:** Linters catch style issues. Focus on logic and correctness.

### Mistake: Requesting Major Rewrites

**Do not:**

```text
Rewrite this entire file to use filter plugins instead of Jinja2
```

**Unless:** The current approach has fundamental flaws

**Do:**

```text
This works fine. For future improvement, consider filter plugins for
better testability. Not required for this PR.
```

### Mistake: Blocking on Personal Preference

**Do not:**

```text
I prefer approach X over approach Y [when both are valid]
```

**Do:**

```text
Both approaches work. I slightly prefer X because [reason], but Y is
fine for this use case.
```

### Mistake: Approving Without Reading

**Do not:**

- Approve because CI passed
- Approve because you trust the author
- Approve without understanding the change

**Do:**

- Read the actual code
- Understand what it does
- Verify it does what PR description says

## Tips for Better Reviews

1. **Review early, review often**
   - Don't let PRs pile up
   - Quick feedback is valuable feedback

2. **Ask questions**
   - If you don't understand something, ask
   - The author may need to add comments or docs

3. **Learn from others**
   - Read other reviews to see different perspectives
   - Note good feedback patterns

4. **Focus on what matters**
   - Correctness and security first
   - Architecture and design second
   - Style last (linters handle most of this)

5. **Be encouraging**
   - Acknowledge good work
   - Frame criticism constructively
   - Remember: we're all learning

## Resources

- **Ansible Lint Rules:** <https://ansible-lint.readthedocs.io/rules/>
- **Ansible Best Practices:**
  <https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html>
- **Red Hat CoP:** <https://redhat-cop.github.io/automation-good-practices/>

## Questions?

- Ask in PR comments
- Tag `@<org>/aap-upgrade-testing-maintainers`
- Create a GitHub Discussion for broader questions
