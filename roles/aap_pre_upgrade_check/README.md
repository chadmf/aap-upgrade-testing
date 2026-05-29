# AAP Pre-Upgrade Check Role

An Ansible role that performs comprehensive health checks on Ansible Automation
Platform (AAP) deployments on OpenShift before upgrades.

## Description

This role validates the health and readiness of your AAP deployment by checking:

- OpenShift node health and resource utilization
- AAP operator status and ClusterServiceVersions (CSVs)
- AAP instance reconciliation status
- Database backend health (embedded or external PostgreSQL)
- Generates a detailed markdown report with findings

## Requirements

- Ansible >= 2.15
- `kubernetes.core` collection
- `kubectl` or `oc` CLI tool installed
- Valid kubeconfig with cluster access
- Permissions to read resources in AAP and database namespaces

## Role Variables

### Required Variables

None - all variables have sensible defaults.

### Optional Variables

#### General Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_kubeconfig_path` | `""` | Path to kubeconfig file (empty uses
default `~/.kube/config`) |
| `aap_namespace` | `ansible-automation-platform` | Namespace where AAP is deployed |
| `aap_database_namespace` | `edb-pg-demo` | Namespace for external PostgreSQL cluster |

#### Report Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_report_output_dir` | `{{ playbook_dir }}/reports` | Directory for
output reports |
| `aap_report_filename` | `pre-upgrade-check-<timestamp>.md` | Report filename |
| `aap_generate_report` | `true` | Generate markdown report |

#### Health Check Thresholds

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_node_cpu_warning_threshold` | `70` | CPU usage % to trigger warnings |
| `aap_node_memory_warning_threshold` | `80` | Memory usage % to trigger
warnings |
| `aap_operator_check_timeout` | `30` | Timeout for operator checks
(seconds) |
| `aap_pod_ready_timeout` | `60` | Timeout for pod readiness checks
(seconds) |

#### Failure Behavior

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_fail_on_degraded_pods` | `false` | Fail playbook if pods are not
ready |
| `aap_fail_on_failed_csv` | `true` | Fail playbook if CSVs are in Failed
state |
| `aap_fail_on_unhealthy_database` | `true` | Fail playbook if database
cluster is unhealthy |

#### Expected Operators

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_expected_operators` | See `defaults/main.yml` | List of expected
operator pod name patterns |

## Dependencies

None.

## Example Playbook

### Basic Usage

```yaml
---
- name: Run AAP pre-upgrade health check
  hosts: localhost
  gather_facts: true
  roles:
    - aap_pre_upgrade_check
```

### Custom Kubeconfig and Namespace

```yaml
---
- name: Run AAP pre-upgrade health check
  hosts: localhost
  gather_facts: true
  vars:
    aap_kubeconfig_path: ~/.kube/kubeconfig-production
    aap_namespace: aap-prod
    aap_database_namespace: postgres-prod
  roles:
    - aap_pre_upgrade_check
```

### Lower Thresholds for Strict Checking

```yaml
---
- name: Strict pre-upgrade health check
  hosts: localhost
  gather_facts: true
  vars:
    aap_node_cpu_warning_threshold: 50
    aap_node_memory_warning_threshold: 60
    aap_fail_on_degraded_pods: true
  roles:
    - aap_pre_upgrade_check
```

### With Tags

```yaml
---
- name: Run specific health checks
  hosts: localhost
  gather_facts: true
  roles:
    - role: aap_pre_upgrade_check
      tags:
        - nodes
        - operators
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `preflight` | Pre-flight checks (kubeconfig, connectivity) |
| `nodes` | Node health and resource checks |
| `infrastructure` | Same as nodes |
| `operators` | AAP operator and CSV checks |
| `aap` | AAP instance status checks |
| `instance` | Same as aap |
| `database` | Database backend health checks |
| `postgres` | Same as database |
| `report` | Report generation only |
| `always` | Always runs (preflight and report if enabled) |

## Example Commands

```bash
# Run all checks
ansible-playbook playbooks/pre_upgrade_check.yml

# Run only node and operator checks
ansible-playbook playbooks/pre_upgrade_check.yml --tags nodes,operators

# Skip report generation
ansible-playbook playbooks/pre_upgrade_check.yml --skip-tags report

# Use custom kubeconfig
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/kubeconfig

# Lower thresholds for warnings
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_node_cpu_warning_threshold=50 \
  -e aap_node_memory_warning_threshold=60
```

## Output

The role produces:

1. **Console output**: Real-time check results and summary
2. **Markdown report**: Detailed findings saved to `aap_report_output_dir`

### Report Sections

- Executive Summary (issues/warnings count)
- Critical Issues (blocks upgrade)
- Warnings (should review)
- Node Health (status, resources, conditions)
- AAP Operator Status (CSVs, pods)
- AAP Instance Status (reconciliation, health)
- Database Backend (cluster, pods, operators)
- Recommendations

## Return Values

The role sets the following fact that can be used in subsequent tasks:

```yaml
aap_check_results:
  timestamp: "2026-05-29T12:34:56Z"
  cluster_version: "v1.34.4"
  nodes: {...}
  operators: {...}
  aap_instance: {...}
  database: {...}
  issues: [...]      # Critical issues found
  warnings: [...]    # Warnings found
```

## Common Issues

### kubernetes.core collection not found

Install the collection:

```bash
ansible-galaxy collection install kubernetes.core
```

### Permission denied errors

Ensure your kubeconfig has proper RBAC permissions:

- Read access to nodes
- Read access to pods, CSVs in AAP namespace
- Read access to database namespace resources

### Metrics not available

If node metrics fail, ensure metrics-server is installed:

```bash
kubectl top nodes
```

## License

Apache-2.0

## Author

Chad Ferman (cferman@redhat.com)
