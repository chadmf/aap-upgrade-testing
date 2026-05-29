# Pull Request

## Description

<!-- Provide a clear and concise description of what this PR does and why -->

## Type of Change

<!-- Mark the relevant option with an "x" -->

- [ ] Feature (new functionality)
- [ ] Fix (bug fix)
- [ ] Documentation (docs update)
- [ ] Security (security fix or improvement)
- [ ] Refactor (code restructuring)
- [ ] Test (test additions or updates)

## Changes Made

<!-- Provide a bulleted list of specific changes -->

-
-
-

## Testing Evidence

<!-- Describe how you tested these changes. Include output, screenshots, or test results -->

```bash
# Example: Commands run and their output

```

## Related Issues

<!-- Link related issues, Jira tickets, or GitHub issues -->

Closes #
Related to #

## Review Checklist

<!-- Ensure all items are checked before requesting review -->

### Quality
- [ ] Passes ansible-lint (production profile)
- [ ] Passes yamllint
- [ ] Syntax check passes
- [ ] Pre-commit hooks pass
- [ ] Documentation updated (README, role docs)

### Security
- [ ] No secrets or credentials in code
- [ ] `no_log: true` used for secret handling tasks
- [ ] Debug output sanitized (no sensitive data)
- [ ] Input validation implemented where needed
- [ ] Security considerations addressed (if applicable)

### Architecture
- [ ] Follows existing patterns and conventions
- [ ] Error handling is consistent
- [ ] Changes are modular and extensible
- [ ] Configuration uses defaults/main.yml (no hardcoded values)

### Testing
- [ ] Tested against real cluster (if applicable)
- [ ] Examples or playbooks demonstrate usage
- [ ] Edge cases considered

## Additional Notes

<!-- Any additional information for reviewers -->
