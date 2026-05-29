# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

Currently in active development. Once 1.0 is released, we will maintain
security updates for the latest stable version.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### Reporting Process

1. **Email:** Send details to **security@example.com** (replace with actual
security contact)

2. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)
   - Your contact information

3. **Response Timeline:**

   - Initial response: Within 48 hours
   - Status update: Within 5 business days
   - Fix timeline: Depends on severity

4. **Disclosure:**

   - We will work with you on responsible disclosure
   - We aim to fix critical vulnerabilities within 30 days
   - Public disclosure after fix is released

### Severity Guidelines

| Severity | Response Time | Examples |
|----------|---------------|----------|
| **Critical** | Same day | Credential exposure, RCE |
| **High** | 1-3 days | Authentication bypass, sensitive data
leak |
| **Medium** | 1-2 weeks | Input validation issues, information
disclosure |
| **Low** | Next release | Minor information leaks, best practice
violations |

## Security Best Practices for Users

### Kubeconfig Security

**Storage:**

- Store kubeconfig in user-only readable location (`chmod 600
~/.kube/config`)
- Never commit kubeconfig to version control
- Use separate kubeconfig files for different environments
- Rotate credentials regularly

**Usage with this role:**

```yaml
# Pass kubeconfig path explicitly
- hosts: localhost
  roles:
    - role: aap_pre_upgrade_check
      vars:
        aap_kubeconfig_path: ~/.kube/production-config
```

### Report Security

**Generated reports may contain sensitive cluster information:**

- Store reports in secure location (restricted file permissions)
- Delete reports after review (especially if they contain connection details)
- Never commit reports to version control (already in `.gitignore`)
- Review report contents before sharing

**Recommended permissions:**

```bash
# Create reports directory with restricted access
mkdir -p ~/aap-reports
chmod 700 ~/aap-reports

# Run playbook to output reports there
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_report_output_dir=~/aap-reports
```

### RBAC Minimum Permissions

This role requires **read-only** access to cluster resources. Use a service
account or kubeconfig with minimal permissions.

**Required Kubernetes Permissions:**

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aap-pre-upgrade-checker
rules:
  # Node information (cluster-scoped)
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: aap-pre-upgrade-checker
  namespace: ansible-automation-platform  # Adjust to your AAP namespace
rules:
  # Pods, Secrets (AAP namespace)
  - apiGroups: [""]
    resources: ["pods", "secrets"]
    verbs: ["get", "list"]

  # ClusterServiceVersions (OLM)
  - apiGroups: ["operators.coreos.com"]
    resources: ["clusterserviceversions"]
    verbs: ["get", "list"]

  # AAP Custom Resource
  - apiGroups: ["aap.ansible.com"]
    resources: ["ansibleautomationplatforms"]
    verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: aap-pre-upgrade-checker-db
  namespace: edb-pg-demo  # Adjust to your database namespace
rules:
  # PostgreSQL Clusters
  - apiGroups: ["postgresql.cnpg.io"]
    resources: ["clusters"]
    verbs: ["get", "list"]

  # Database Pods
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

**Do NOT grant:**

- Cluster-admin access
- Write permissions (create, update, delete, patch)
- Access to namespaces not required for AAP

### Credential Handling

**The role extracts database connection information from Kubernetes
secrets.**

**Security measures implemented:**

- Secrets only read, never modified
- Base64 decoding happens in-memory
- Credentials not written to disk (except in kubeconfig which already
exists)
- Facts containing credentials cleared after use

**User responsibilities:**

- Ensure kubeconfig has appropriate permissions
- Review Ansible output for any unexpected credential exposure
- Rotate credentials if exposure suspected
- Monitor access to Kubernetes cluster

### Running in CI/CD

**If running this role in CI/CD pipelines:**

1. **Use short-lived credentials:**

   - Service account tokens with expiration
   - OIDC authentication when possible

2. **Restrict CI/CD access:**

   - Separate kubeconfig for CI/CD
   - Minimal RBAC permissions
   - Audit logging enabled

3. **Secure artifacts:**

   - Encrypt reports before storage
   - Delete reports after processing
   - Restrict access to CI/CD secrets

4. **Audit trail:**

   - Log when checks run
   - Track who triggered the check
   - Monitor for anomalies

## Known Security Considerations

### Current Implementation

1. **Database credentials in facts:**

   - Database hostnames stored in Ansible facts
   - Passwords NOT stored (only queried via Kubernetes API)
   - Facts cleared at end of play

2. **Debug output:**

   - May contain cluster topology information
   - Connection strings (hostnames, ports) may be visible
   - No passwords or tokens in debug output

3. **Reports contain:**

   - ✅ Cluster version, node information (non-sensitive)
   - ✅ Operator status, AAP version (non-sensitive)
   - ⚠️ Database hostnames and connection details (internal only)
   - ❌ No passwords, tokens, or credentials

### Hardening Recommendations

1. **Restrict playbook execution:**

   ```bash
   # Run from bastion host only
   # Use Ansible Vault for any sensitive variables
   # Audit who can run the playbook
   ```

2. **Network security:**

   ```bash
   # Ensure Kubernetes API access is over TLS
   # Verify certificate validation enabled
   # Use private network for cluster communication
   ```

3. **Monitoring:**

   ```bash
   # Enable audit logging on Kubernetes cluster
   # Monitor for unusual API access patterns
   # Track when pre-upgrade checks run
   ```

## Security Update Process

When a security vulnerability is reported and confirmed:

1. **Assessment:** Security team evaluates severity and impact
2. **Fix Development:** Patch developed and tested
3. **Testing:** Security fix validated
4. **Release:** Security update released
5. **Notification:** Users notified via GitHub Security Advisory
6. **Disclosure:** Public disclosure after users have had time to update

## Security Audit History

| Date | Type | Findings | Status |
|------|------|----------|--------|
| 2026-05-29 | Initial Development | Multiple findings documented |
In Progress |

Detailed findings tracked in `.github/SECURITY_REVIEW.md`

## Contact

For security concerns or questions:

- **Security Email:** security@example.com
- **GitHub Issues:** For non-sensitive questions only

## References

- [OWASP Ansible Security]
  <https://cheatsheetseries.owasp.org/cheatsheets/Ansible_Security_Cheat_Sheet.html>
- [Kubernetes Security Best Practices]
  <https://kubernetes.io/docs/concepts/security/security-checklist/>
- [Ansible Vault Documentation]
  <https://docs.ansible.com/ansible/latest/user_guide/vault.html>
