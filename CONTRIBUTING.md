# Contributing to AAP Upgrade Testing

Thank you for your interest in contributing to the AAP Upgrade Testing project! This document
provides guidelines for contributing code, documentation, and improvements.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Quality Standards](#quality-standards)
- [Architectural Guidelines](#architectural-guidelines)
- [Security Requirements](#security-requirements)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project follows Red Hat's Community Code of Conduct. Be respectful, professional, and collaborative.

## Getting Started

### Prerequisites

- Ansible >= 2.15
- Python >= 3.11
- `kubernetes.core` collection
- `kubectl` or `oc` CLI
- Pre-commit hooks (recommended)

### Initial Setup

1. **Fork the repository** on GitHub

2. **Clone your fork**:

   ```bash
   git clone git@github.com:<your-username>/aap-upgrade-testing.git
   cd aap-upgrade-testing
   ```

3. **Add upstream remote**:

   ```bash
   git remote add upstream git@github.com:<org>/aap-upgrade-testing.git
   ```

4. **Install pre-commit hooks** (recommended):

   ```bash
   pip install pre-commit
   pre-commit install
   ```

5. **Install development dependencies**:

   ```bash
   pip install ansible-core ansible-lint yamllint
   ansible-galaxy collection install -r requirements.yml
   ```

## Development Workflow

### Branch Naming Convention

Use descriptive branch names with prefixes:

- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `security/` - Security fixes
- `test/` - Test additions or updates

Examples:

```text
feature/add-etcd-health-check
fix/database-password-logging
docs/update-troubleshooting-guide
security/sanitize-debug-output
```

### Making Changes

1. **Sync with upstream**:

   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

2. **Create a feature branch**:

   ```bash
   git checkout -b feature/my-new-feature
   ```

3. **Make your changes** following quality standards (see below)

4. **Test locally**:

   ```bash
   # Run linters
   yamllint -c .yamllint.yml .
   ansible-lint --profile production

   # Syntax check
   ansible-playbook --syntax-check playbooks/pre_upgrade_check.yml

   # Test against a cluster (optional but recommended)
   ansible-playbook playbooks/pre_upgrade_check.yml \
     -e aap_kubeconfig_path=~/.kube/test-config
   ```

5. **Commit your changes**:

   ```bash
   git add .
   git commit -m "feat(check-nodes): add disk space validation"
   ```

6. **Push to your fork**:

   ```bash
   git push origin feature/my-new-feature
   ```

7. **Create a Pull Request** on GitHub

## Quality Standards

### Linting

All code must pass the following linters:

- **yamllint** - YAML formatting (`.yamllint.yml`)
- **ansible-lint** - Ansible best practices (production profile)
- **markdownlint** - Documentation formatting

Run locally before committing:

```bash
pre-commit run --all-files
```

### Ansible Best Practices

- Use descriptive task names with proper prefixing
- Include `changed_when` and `failed_when` where appropriate
- Use `no_log: true` for tasks handling secrets
- Validate inputs before use
- Document all role variables in `defaults/main.yml`
- Update role README when adding features

### Documentation

- Update README.md when adding features or changing behavior
- Use markdown format for all documentation
- Keep line length under 120 characters
- Include examples and usage instructions

## Architectural Guidelines

### Error Handling

- Use consistent error handling patterns across task files
- Avoid `failed_when: false` without proper justification and documentation
- Provide actionable error messages
- Implement graceful degradation for optional features

### Modularity

- Keep task files focused on single responsibilities
- Extract complex Jinja2 templates to filter plugins or vars files
- Use tags appropriately for selective execution
- Design for extensibility - new checks should be easy to add

### Configuration Management

- Use `defaults/main.yml` for all configurable values
- Avoid hardcoded paths or values in task files
- Document threshold values and their purpose
- Provide sensible defaults

## Security Requirements

### Critical Security Practices

1. **Never log secrets**:

   ```yaml
   - name: Extract database password
     set_fact:
       db_password: "{{ secret_data | b64decode }}"
     no_log: true  # REQUIRED for secrets
   ```

2. **Validate all inputs**:

   ```yaml
   - name: Validate kubeconfig path
     assert:
       that:
         - aap_kubeconfig_path is defined
         - aap_kubeconfig_path | length > 0
         - aap_kubeconfig_path is match('^[a-zA-Z0-9/_.-]+$')
   ```

3. **Sanitize debug output**:
   - Review all `debug` tasks for sensitive data
   - Use `var` parameter carefully
   - Redact credentials and connection strings

4. **Secure report generation**:
   - Redact or make sensitive data optional in reports
   - Document report storage best practices
   - Set appropriate file permissions

### Security Review Triggers

Changes requiring security review (automatic CODEOWNERS assignment):
- Modifying `check_database.yml`
- Changes to authentication/authorization
- Input validation changes
- Debug/logging output changes
- RBAC requirement changes

See `.github/SECURITY_REVIEW.md` for the complete security review checklist.

## Commit Guidelines

### Commit Message Format

Use conventional commits:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Test additions
- `chore` - Maintenance tasks
- `security` - Security fixes

**Examples:**

```text
feat(database): add PostgreSQL cluster version check

Add validation for PostgreSQL cluster version compatibility
with AAP requirements. Warns if cluster version is below
minimum supported version.

Closes #42
```

```text
security(check-database): add no_log to credential extraction

Prevent database credentials from appearing in Ansible output
by adding no_log: true to all secret extraction tasks.

Fixes: CVE-2024-XXXX
```

## Pull Request Process

### Before Creating PR

1. ✅ Code passes all linters (`pre-commit run --all-files`)
2. ✅ Ansible syntax check passes
3. ✅ Tested against a real cluster (if applicable)
4. ✅ Documentation updated
5. ✅ Security considerations addressed

### PR Template Checklist

When you create a PR, complete the pull request template checklist:

- [ ] Passes ansible-lint (production profile)
- [ ] Passes yamllint
- [ ] Syntax check passes
- [ ] No secrets in code or output
- [ ] Documentation updated
- [ ] Security considerations addressed (if applicable)
- [ ] Architectural patterns followed
- [ ] Tested against real cluster (if applicable)

### Review Process

1. **Automated checks** run via GitHub Actions
2. **Code review** by maintainer (architecture, logic, style)
3. **Architecture review** (if needed - for structural changes)
4. **Security review** (if needed - for security-sensitive changes)
5. **Approval and merge**

See `docs/REVIEW_PROCESS.md` for detailed review workflow.

### Review SLAs

- Initial code review: 2 business days
- Architecture review: 3 business days
- Security review: 3 business days
- Critical security fixes: Same day

## Getting Help

- Create an issue for questions or discussions
- Tag maintainers for urgent matters
- Join community discussions (Slack, mailing list)

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 License.
