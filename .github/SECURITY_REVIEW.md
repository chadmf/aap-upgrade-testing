# Security Review Checklist

This document guides security architects in reviewing code changes for security vulnerabilities, credential handling, and compliance with security best practices.

## Review Scope

Security review is required for:

- Secret or credential handling
- Authentication or authorization changes
- Input validation changes
- Debug or logging output changes
- RBAC requirement changes
- Network communication or API calls
- File system operations
- Report generation (sensitive data exposure)

## Critical Security Hotspots

### Known Issues in Current Codebase

| File | Lines | Issue | Severity | Status |
|------|-------|-------|----------|--------|
| `roles/aap_pre_upgrade_check/tasks/check_database.yml` | 14-15, 40 | Base64 decoded credentials in facts without `no_log` | **HIGH** | 🔴 Needs Fix |
| `roles/aap_pre_upgrade_check/tasks/*.yml` | Various | Debug output may leak cluster info | **MEDIUM** | ⚠️ Review |
| `roles/aap_pre_upgrade_check/templates/pre_upgrade_report.md.j2` | 153-157 | Database connection details in report | **MEDIUM** | ⚠️ Review |
| `roles/aap_pre_upgrade_check/tasks/preflight.yml` | 4 | `aap_kubeconfig_path` not validated | **MEDIUM** | ⚠️ Needs Fix |
| README.md | - | No RBAC requirements documented | **LOW** | 📝 Document |

## Security Review Categories

### 1. Authentication & Authorization

**Objective:** Ensure proper authentication and least-privilege access

**Review Points:**

- [ ] Kubeconfig handling follows best practices
  - No kubeconfig content logged or output
  - Path validation before use
  - TLS verification enabled (not `insecure-skip-tls-verify`)
- [ ] No hardcoded credentials in code or variables
- [ ] RBAC requirements documented
  - Minimum required permissions listed
  - Service account usage documented (if applicable)
- [ ] External authentication handled securely
  - No credentials in environment variables (unless documented)
  - Token storage follows best practices

**Known Issues:**

```yaml
# roles/aap_pre_upgrade_check/tasks/preflight.yml
# ISSUE: aap_kubeconfig_path not validated before use
- name: Test cluster connectivity
  kubernetes.core.k8s_cluster_info:
    kubeconfig: "{{ aap_k8s_kubeconfig | default(omit) }}"
```

**Fix Required:**
```yaml
- name: Validate kubeconfig path
  ansible.builtin.assert:
    that:
      - aap_kubeconfig_path is not defined or (aap_kubeconfig_path | length > 0 and aap_kubeconfig_path is match('^[a-zA-Z0-9/_.-]+$'))
    fail_msg: "Invalid kubeconfig path"
  when: aap_kubeconfig_path is defined
```

---

### 2. Secret Management

**Objective:** Secrets are never logged, stored inappropriately, or exposed

**Review Points:**

- [ ] All secret extraction uses `no_log: true`
- [ ] Secrets not stored in Ansible facts beyond necessary scope
- [ ] No secrets in debug output
- [ ] No secrets in reports or generated files
- [ ] Secret facts cleared after use (if possible)
- [ ] Base64 decoded values handled securely

**Critical Example - Needs Fix:**

```yaml
# roles/aap_pre_upgrade_check/tasks/check_database.yml (lines 14-15)
# CRITICAL: Missing no_log for credential extraction
- name: Extract database host from secret
  ansible.builtin.set_fact:
    db_host: "{{ db_secret_info.resources[0].data.host | b64decode }}"
    db_type: "{{ db_secret_info.resources[0].data.type | b64decode | default('postgresql') }}"
  when:
    - db_secret_info.resources is defined
    - db_secret_info.resources | length > 0
```

**Must Be:**
```yaml
- name: Extract database host from secret
  ansible.builtin.set_fact:
    db_host: "{{ db_secret_info.resources[0].data.host | b64decode }}"
    db_type: "{{ db_secret_info.resources[0].data.type | b64decode | default('postgresql') }}"
  no_log: true  # REQUIRED
  when:
    - db_secret_info.resources is defined
    - db_secret_info.resources | length > 0
```

**Secret Handling Checklist:**

- [ ] `no_log: true` on all tasks that:
  - Extract secrets from Kubernetes (b64decode)
  - Access password/token variables
  - Query credential stores
- [ ] Facts containing secrets have `no_log: true`
- [ ] Reports don't include:
  - Passwords, tokens, API keys
  - Full connection strings (redact credentials)
  - Certificate contents
  - Private keys

---

### 3. Input Validation

**Objective:** All user inputs are validated to prevent injection attacks

**Review Points:**

- [ ] File paths validated before use
  - No path traversal (../)
  - Whitelist of allowed characters
  - Absolute path requirements enforced
- [ ] Namespace names validated (Kubernetes naming rules)
- [ ] Numeric thresholds validated (range checks)
- [ ] No command injection vulnerabilities
  - Avoid shell: true when possible
  - Use module parameters, not string concatenation
- [ ] YAML/JSON input parsed safely

**Examples:**

Path Validation:
```yaml
- name: Validate kubeconfig path
  ansible.builtin.assert:
    that:
      - aap_kubeconfig_path is match('^[a-zA-Z0-9/_.-]+$')
      - aap_kubeconfig_path does not contain '..'
```

Threshold Validation:
```yaml
- name: Validate thresholds
  ansible.builtin.assert:
    that:
      - aap_node_cpu_warning_threshold >= 0
      - aap_node_cpu_warning_threshold <= 100
```

Command Injection Prevention:
```yaml
# BAD - potential injection
- name: Check namespace
  ansible.builtin.shell: |
    kubectl get pods -n {{ namespace }}

# GOOD - use module parameters
- name: Check namespace
  kubernetes.core.k8s_info:
    kind: Pod
    namespace: "{{ namespace }}"
```

---

### 4. Data Exposure

**Objective:** Sensitive data not leaked via logs, output, or reports

**Review Points:**

- [ ] Debug output reviewed for sensitive data
  - No connection strings with credentials
  - No API tokens or keys
  - Cluster topology acceptable (not credentials)
- [ ] Reports sanitized of credentials
  - Connection strings redacted
  - Optional sections for sensitive data
- [ ] Error messages don't leak internal details
  - Stack traces sanitized
  - File paths reviewed (may reveal structure)
- [ ] Logs don't contain sensitive data
  - Audit ansible.log for secrets
  - Check report generation output

**Report Template Review:**

```yaml
# roles/aap_pre_upgrade_check/templates/pre_upgrade_report.md.j2
# Lines 153-157 - Review for sensitive data

**Connection Details**:
- **Host**: {{ aap_check_results.database.host }}  # ← Acceptable (internal hostname)
- **Namespace**: {{ aap_check_results.database.namespace }}  # ← Acceptable

# If report included password or full connection string with credentials - NOT ACCEPTABLE
```

**Sanitization Examples:**

```yaml
# Redact credentials from connection strings
- name: Generate safe connection string
  set_fact:
    safe_connection_string: "{{ connection_string | regex_replace('://([^:]+):([^@]+)@', '://***:***@') }}"
```

---

### 5. File System Security

**Objective:** Files created securely with appropriate permissions

**Review Points:**

- [ ] Report directory permissions documented
  - Default: user-only (0700) or group-readable (0750)
  - No world-readable sensitive files
- [ ] Temporary files handled securely
  - Created in secure location
  - Cleaned up after use
  - Proper permissions set
- [ ] No race conditions in file creation
- [ ] File ownership appropriate

**Example:**

```yaml
- name: Create report output directory
  ansible.builtin.file:
    path: "{{ aap_report_output_dir }}"
    state: directory
    mode: "0755"  # ← Review: Is this appropriate for sensitive reports?
  delegate_to: localhost
```

**Recommendation:**
```yaml
mode: "0750"  # Group-readable, not world-readable
```

---

### 6. Network Security

**Objective:** Network communications are secure and validated

**Review Points:**

- [ ] Cluster connections use TLS
- [ ] Kubeconfig TLS validation enabled
  - No `insecure-skip-tls-verify: true`
- [ ] No plaintext credentials transmitted
- [ ] API calls to external services use HTTPS
- [ ] Certificate validation enabled

**Kubernetes API Security:**

```yaml
# Ensure TLS validation (kubernetes.core handles this by default)
- name: Query cluster
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Node
    kubeconfig: "{{ aap_k8s_kubeconfig | default(omit) }}"
    validate_certs: true  # Explicit (default is true)
```

---

### 7. Dependency Security

**Objective:** Dependencies are from trusted sources and have no known vulnerabilities

**Review Points:**

- [ ] Collections from trusted sources (Ansible Galaxy, Red Hat Automation Hub)
- [ ] Version pinning for collections
  - `requirements.yml` specifies versions
- [ ] No known vulnerabilities in dependencies
  - Check CVE databases
  - Review ansible-lint security rules
- [ ] Dependency updates tracked

**Example requirements.yml:**
```yaml
---
collections:
  - name: kubernetes.core
    version: ">=2.4.0,<3.0.0"  # Pin to major version
    source: https://galaxy.ansible.com
```

---

### 8. RBAC & Least Privilege

**Objective:** Document and enforce minimum required permissions

**Review Points:**

- [ ] RBAC requirements documented in README
  - Minimum Kubernetes permissions listed
  - Service account requirements (if used)
  - Namespace access requirements
- [ ] Role requests least-privilege access
  - Only read operations (no write)
  - Specific resource types listed
- [ ] No cluster-admin requirements

**Required Documentation Example:**

```markdown
## RBAC Requirements

This role requires read access to the following Kubernetes resources:

- **Nodes:** `get`, `list` (cluster-scoped)
- **Pods:** `get`, `list` (namespace: aap_namespace)
- **ClusterServiceVersions:** `get`, `list` (namespace: aap_namespace)
- **AnsibleAutomationPlatform CR:** `get`, `list` (namespace: aap_namespace)
- **Secrets:** `get` (namespace: aap_namespace) - only for database config
- **PostgreSQL Clusters:** `get`, `list` (namespace: aap_database_namespace)

**Example ClusterRole:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aap-pre-upgrade-checker
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
  # ... etc
```

---

## Security Review Decision Matrix

| Severity | CVSS Score | Action Required | Timeline |
|----------|------------|-----------------|----------|
| **Critical** | 9.0-10.0 | Block merge, immediate fix | Same day |
| **High** | 7.0-8.9 | Block merge, fix before merge | 1-2 days |
| **Medium** | 4.0-6.9 | Request changes, fix in current PR | Before merge |
| **Low** | 0.1-3.9 | Document for future work | Optional |
| **Informational** | 0.0 | Best practice suggestion | Optional |

---

## Vulnerability Classification

### Critical (CVSS 9.0+)

- Hardcoded credentials in code
- Remote code execution vulnerabilities
- Privilege escalation without authentication
- Sensitive data exposure to unauthorized users

### High (CVSS 7.0-8.9)

- Credentials logged or in output (can be captured)
- Missing input validation on security-sensitive operations
- Insecure credential storage (plaintext files, etc.)
- Authentication bypass

### Medium (CVSS 4.0-6.9)

- Missing `no_log` on non-critical secret handling
- Sensitive data in reports (but restricted access)
- Path traversal with limited impact
- Information disclosure (non-sensitive)

### Low (CVSS 0.1-3.9)

- Missing RBAC documentation
- Overly permissive file permissions (low impact)
- Verbose error messages (limited info leak)
- Missing security headers (low impact)

---

## Review Approval Checklist

Before approving:

- [ ] All critical issues fixed
- [ ] All high issues fixed or documented with mitigation
- [ ] Medium issues addressed or accepted risk documented
- [ ] `no_log: true` present on all secret handling
- [ ] Input validation implemented
- [ ] Reports sanitized of credentials
- [ ] RBAC requirements documented (if changed)
- [ ] Dependencies reviewed for vulnerabilities
- [ ] Security test cases added (if applicable)

---

## Review Comments Template

```markdown
## Security Review - [Date]

### Summary
[Approved / Approved with changes / Changes required / Blocked]

### Findings

#### Critical (Block Merge)
- None / [List with CVSS scores and line references]

#### High (Fix Before Merge)
- None / [List with line references]

#### Medium (Address in PR)
- None / [List with recommendations]

#### Low / Informational
- [Optional improvements]

### Required Actions
1. [Specific fix required]
2. [Documentation update needed]

### Decision
- [ ] Approved
- [ ] Approved with changes
- [ ] Changes required before merge
- [ ] Blocked (critical issue)

**Reviewer:** [Name]
**Date:** [YYYY-MM-DD]
**CVSS Scores:** [If applicable]
```

---

## Remediation Priority

1. **Immediate (Critical/High):**
   - Add `no_log: true` to credential extraction (check_database.yml:14-15)
   - Add input validation for `aap_kubeconfig_path`
   - Audit all debug output for sensitive data

2. **Before Merge (Medium):**
   - Document RBAC requirements in README
   - Review report template for sensitive data exposure
   - Add file permission documentation for reports

3. **Future Enhancement (Low):**
   - Add security test cases
   - Implement automated secret scanning in CI
   - Create security hardening guide

---

## References

- OWASP Top 10: https://owasp.org/www-project-top-ten/
- Ansible Security Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#best-practices-for-variables-and-vaults
- CVSS Calculator: https://www.first.org/cvss/calculator/3.1
- CWE Database: https://cwe.mitre.org/
