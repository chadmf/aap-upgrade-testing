# AAP Upgrade Testing

Ansible automation for validating AAP deployments on OpenShift before and during upgrades.

## Overview

This repository contains Ansible roles and playbooks for:
- Pre-upgrade health checks of AAP on OpenShift
- Node health and resource utilization validation
- Operator status verification
- Database backend health checks
- Automated report generation

## Quick Start

### Prerequisites

```bash
# Install required Ansible collection
ansible-galaxy collection install kubernetes.core

# Verify kubectl/oc is available
kubectl version --client

# Verify cluster connectivity
kubectl cluster-info
```

### Run Pre-Upgrade Check

For the **chadsno2026** cluster:

```bash
ansible-playbook playbooks/check_chadsno2026.yml
```

For other clusters:

```bash
# Using default kubeconfig
ansible-playbook playbooks/pre_upgrade_check.yml

# Using custom kubeconfig
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/custom-config
```

## Repository Structure

```
.
├── ansible.cfg                           # Ansible configuration
├── inventory                             # Inventory file (localhost)
├── playbooks/
│   ├── pre_upgrade_check.yml            # Generic pre-upgrade check
│   └── check_chadsno2026.yml            # chadsno2026-specific check
├── roles/
│   └── aap_pre_upgrade_check/           # Main health check role
│       ├── defaults/main.yml            # Default variables
│       ├── meta/main.yml                # Role metadata
│       ├── tasks/                       # Task files
│       │   ├── main.yml
│       │   ├── preflight.yml
│       │   ├── check_nodes.yml
│       │   ├── check_operators.yml
│       │   ├── check_aap_instance.yml
│       │   ├── check_database.yml
│       │   └── generate_report.yml
│       ├── templates/
│       │   └── pre_upgrade_report.md.j2 # Report template
│       └── README.md                    # Role documentation
├── reports/                             # Generated reports (created on first run)
├── chadsno2026-status-report.md        # Manual investigation report
└── README.md                            # This file
```

## Playbooks

### `playbooks/pre_upgrade_check.yml`

Generic playbook for any AAP deployment. Override variables as needed:

```yaml
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/config \
  -e aap_namespace=ansible-automation-platform \
  -e aap_database_namespace=edb-pg-demo
```

### `playbooks/check_chadsno2026.yml`

Pre-configured for the chadsno2026 cluster with proper kubeconfig and namespace settings.

## Role: aap_pre_upgrade_check

See [roles/aap_pre_upgrade_check/README.md](roles/aap_pre_upgrade_check/README.md) for detailed documentation.

### Key Features

- ✓ Node health and resource utilization checks
- ✓ AAP operator CSV status validation
- ✓ Operator pod readiness verification
- ✓ AAP instance reconciliation status
- ✓ External PostgreSQL cluster health
- ✓ Database operator upgrade status
- ✓ Configurable warning thresholds
- ✓ Automated markdown report generation

### What Gets Checked

1. **OpenShift Nodes**
   - Node status (Ready/NotReady)
   - CPU and memory utilization
   - OS version and kernel
   - Container runtime version

2. **AAP Operators**
   - ClusterServiceVersion (CSV) status
   - Operator pod health and readiness
   - Operator upgrade status
   - Expected operators presence

3. **AAP Instance**
   - Custom resource status
   - Reconciliation success/failure
   - Ansible playbook run results
   - Version and configuration

4. **Database Backend**
   - Database type (embedded vs external)
   - PostgreSQL cluster health
   - Database pod status
   - Database operator upgrade status

### Configuration

Key variables (see `roles/aap_pre_upgrade_check/defaults/main.yml` for all options):

```yaml
# Cluster configuration
aap_kubeconfig_path: ""                    # Default: use ~/.kube/config
aap_namespace: ansible-automation-platform
aap_database_namespace: edb-pg-demo

# Warning thresholds
aap_node_cpu_warning_threshold: 70         # CPU % warning
aap_node_memory_warning_threshold: 80      # Memory % warning

# Failure behavior
aap_fail_on_degraded_pods: false           # Fail if pods not ready
aap_fail_on_failed_csv: true               # Fail if CSV in Failed state
aap_fail_on_unhealthy_database: true       # Fail if DB unhealthy

# Report settings
aap_generate_report: true
aap_report_output_dir: "{{ playbook_dir }}/reports"
```

## Using Tags

Run specific checks:

```bash
# Only check nodes
ansible-playbook playbooks/pre_upgrade_check.yml --tags nodes

# Only check operators
ansible-playbook playbooks/pre_upgrade_check.yml --tags operators

# Check nodes and database
ansible-playbook playbooks/pre_upgrade_check.yml --tags nodes,database

# Skip report generation
ansible-playbook playbooks/pre_upgrade_check.yml --skip-tags report
```

Available tags:
- `preflight` - Pre-flight validation
- `nodes` / `infrastructure` - Node health checks
- `operators` - AAP operator checks
- `aap` / `instance` - AAP instance checks
- `database` / `postgres` - Database backend checks
- `report` - Report generation

## Reports

Reports are generated in `reports/` with timestamp:
```
reports/pre-upgrade-check-20260529T123456.md
reports/chadsno2026-pre-upgrade-20260529T123456.md
```

### Report Contents

- Executive summary (issues/warnings count)
- Critical issues (must fix before upgrade)
- Warnings (should review)
- Node health details
- Operator status and CSVs
- AAP instance reconciliation status
- Database cluster health
- Recommendations

## Example Workflow

1. **Pre-upgrade validation**:
   ```bash
   ansible-playbook playbooks/check_chadsno2026.yml
   ```

2. **Review the report**:
   ```bash
   cat reports/chadsno2026-pre-upgrade-*.md
   ```

3. **Address any issues found**

4. **Re-run validation**:
   ```bash
   ansible-playbook playbooks/check_chadsno2026.yml
   ```

5. **Proceed with upgrade when all checks pass**

## Common Scenarios

### Strict Pre-Upgrade Check

Lower thresholds and fail on any degraded pods:

```bash
ansible-playbook playbooks/pre_upgrade_check.yml \
  -e aap_node_cpu_warning_threshold=50 \
  -e aap_node_memory_warning_threshold=60 \
  -e aap_fail_on_degraded_pods=true
```

### Quick Operator Status Check

Skip node and database checks:

```bash
ansible-playbook playbooks/pre_upgrade_check.yml \
  --tags operators,aap
```

### Generate Report Only

If you've already run checks and just want to regenerate the report:

```bash
ansible-playbook playbooks/pre_upgrade_check.yml \
  --tags report
```

## Troubleshooting

### kubernetes.core collection not found

```bash
ansible-galaxy collection install kubernetes.core
```

### Permission errors

Ensure your kubeconfig has read access to:
- Nodes
- Pods, CSVs in AAP namespace
- Resources in database namespace

### No metrics available

Ensure metrics-server is running:
```bash
kubectl top nodes
```

If metrics are unavailable, the role continues but metrics fields show "N/A".

## chadsno2026 Cluster

For the chadsno2026 cluster specifically:

- **Kubeconfig**: `~/.kube/kubeconfig-noingress`
- **Context**: `admin`
- **AAP Namespace**: `ansible-automation-platform`
- **Database Namespace**: `edb-pg-demo`
- **Database Cluster**: `demo-pg` (cloud-native-postgresql)

Use the dedicated playbook:
```bash
ansible-playbook playbooks/check_chadsno2026.yml
```

## Manual Investigation

See [chadsno2026-status-report.md](chadsno2026-status-report.md) for a detailed manual investigation report of the chadsno2026 cluster from 2026-05-29.

## License

Apache-2.0

## Author

Chad Ferman (cferman@redhat.com)
