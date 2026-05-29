# AAP Upgrade Testing

Ansible automation for validating AAP deployments on OpenShift before and during upgrades.

## Overview

This repository contains Ansible roles and playbooks for:

- Pre-upgrade health checks of AAP on OpenShift
- Node health and resource utilization validation
- Operator status verification
- Database backend health checks
- Automated report generation

**Runs in the same execution environment (container) that AAP uses** for maximum compatibility.

## Quick Start

### Prerequisites

**Container Engine** (Podman or Docker):

```bash
# macOS - Install Podman
brew install podman

# Initialize and start Podman machine (macOS only)
podman machine init
podman machine start

# Pull execution environment image
podman pull quay.io/ansible/creator-ee:latest

# Verify
podman run --rm quay.io/ansible/creator-ee:latest ansible --version
```

**Cluster Access**:

```bash
# Verify kubectl/oc is available and configured
kubectl version --client
kubectl cluster-info
```

### Run Pre-Upgrade Check

#### Using Helper Script (Recommended)

Basic execution:

```bash
./run-in-ee.sh playbooks/pre_upgrade_check.yml
```

With options:

```bash
# With tags
./run-in-ee.sh playbooks/pre_upgrade_check.yml --tags operators,database

# Check mode (dry run)
./run-in-ee.sh playbooks/pre_upgrade_check.yml --check

# With extra variables
./run-in-ee.sh playbooks/pre_upgrade_check.yml \
  -e aap_namespace=my-namespace \
  -e aap_kubeconfig_path=~/.kube/config \
  -e aap_node_cpu_warning_threshold=50
```

#### Using Podman/Docker Directly

```bash
podman run --rm -it \
  -v ~/.kube:/runner/.kube:Z \
  -v $(pwd):/runner/project:Z \
  -v $(pwd)/reports:/runner/project/reports:Z,rw \
  -e KUBECONFIG=/runner/.kube/kubeconfig-noingress \
  -e ANSIBLE_STDOUT_CALLBACK=default \
  -w /runner/project \
  quay.io/ansible/creator-ee:latest \
  ansible-playbook playbooks/pre_upgrade_check.yml
```

**For Docker**, remove the `:Z` labels:

```bash
docker run --rm -it \
  -v ~/.kube:/runner/.kube \
  -v $(pwd):/runner/project \
  -v $(pwd)/reports:/runner/project/reports \
  -e KUBECONFIG=/runner/.kube/kubeconfig-noingress \
  -e ANSIBLE_STDOUT_CALLBACK=default \
  -w /runner/project \
  quay.io/ansible/creator-ee:latest \
  ansible-playbook playbooks/pre_upgrade_check.yml
```

## Why Use Containers?

| Benefit | Description |
|---------|-------------|
| **AAP Compatibility** | Same runtime environment as AAP uses |
| **Reproducibility** | Identical execution across all systems |
| **Dependency Isolation** | No local Python/collection conflicts |
| **Version Consistency** | Fixed Ansible and collection versions |
| **No Setup Required** | Everything bundled in the container |

## Repository Structure

```text
.
├── ansible-navigator.yml                 # Navigator config (optional)
├── ansible.cfg                           # Ansible configuration
├── inventory                             # Inventory file (localhost)
├── run-in-ee.sh                         # Helper script for container execution
├── playbooks/
│   ├── pre_upgrade_check.yml            # Generic pre-upgrade check
│   ├── check_chadsno2026.yml            # Example: chadsno2026 cluster
│   └── check_aap_lab.yml                # Example: aap-lab cluster
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
└── docs/                                # Documentation
```

## Playbooks

### `playbooks/pre_upgrade_check.yml`

Generic playbook for any AAP deployment. Override variables as needed:

```bash
./run-in-ee.sh playbooks/pre_upgrade_check.yml \
  -e aap_kubeconfig_path=~/.kube/config \
  -e aap_namespace=ansible-automation-platform \
  -e aap_database_namespace=edb-pg-demo
```

### Cluster-Specific Playbooks

Create cluster-specific playbooks by copying `pre_upgrade_check.yml` and setting variables:

```yaml
---
- name: Check AAP Deployment
  hosts: localhost
  gather_facts: true

  vars:
    aap_kubeconfig_path: ~/.kube/my-cluster-config
    aap_namespace: ansible-automation-platform
    aap_database_namespace: postgres-operator
    aap_report_filename: "my-cluster-pre-upgrade-{{ ansible_date_time.iso8601_basic_short }}.md"

  roles:
    - aap_pre_upgrade_check
```

Examples in this repo:
- `check_chadsno2026.yml` - chadsno2026 cluster configuration
- `check_aap_lab.yml` - aap-lab cluster configuration

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
./run-in-ee.sh playbooks/pre_upgrade_check.yml --tags nodes

# Only check operators
./run-in-ee.sh playbooks/pre_upgrade_check.yml --tags operators

# Check nodes and database
./run-in-ee.sh playbooks/pre_upgrade_check.yml --tags nodes,database

# Skip report generation
./run-in-ee.sh playbooks/pre_upgrade_check.yml --skip-tags report
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

```text
reports/pre-upgrade-check-20260529T123456.md
reports/my-cluster-pre-upgrade-20260529T123456.md
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
   ./run-in-ee.sh playbooks/pre_upgrade_check.yml
   ```

2. **Review the report**:

   ```bash
   cat reports/pre-upgrade-check-*.md
   ```

3. **Address any issues found**

4. **Re-run validation**:

   ```bash
   ./run-in-ee.sh playbooks/pre_upgrade_check.yml
   ```

5. **Proceed with upgrade when all checks pass**

## Common Scenarios

### Strict Pre-Upgrade Check

Lower thresholds and fail on any degraded pods:

```bash
./run-in-ee.sh playbooks/pre_upgrade_check.yml \
  -e aap_node_cpu_warning_threshold=50 \
  -e aap_node_memory_warning_threshold=60 \
  -e aap_fail_on_degraded_pods=true
```

### Quick Operator Status Check

Skip node and database checks:

```bash
./run-in-ee.sh playbooks/pre_upgrade_check.yml \
  --tags operators,aap
```

### Syntax Check Before Running

```bash
./run-in-ee.sh playbooks/pre_upgrade_check.yml --syntax-check
```

### Dry Run (Check Mode)

```bash
./run-in-ee.sh playbooks/pre_upgrade_check.yml --check
```

## Execution Environment Details

The container includes:

- **Image**: `quay.io/ansible/creator-ee:latest`
- **Ansible**: 2.16.3
- **Python**: 3.12.1
- **Collections**:
  - kubernetes.core 3.1.0
  - ansible.posix
  - community.general
  - And many others

Verify what's in the container:

```bash
# Check Ansible version
podman run --rm quay.io/ansible/creator-ee:latest ansible --version

# List collections
podman run --rm quay.io/ansible/creator-ee:latest \
  ansible-galaxy collection list

# Check kubernetes.core specifically
podman run --rm quay.io/ansible/creator-ee:latest \
  ansible-galaxy collection list | grep kubernetes.core
```

## Volume Mounts Explained

| Host Path | Container Path | Purpose | Options |
|-----------|---------------|---------|---------|
| `~/.kube` | `/runner/.kube` | Kubeconfig access | `:Z` (Podman/SELinux) |
| `$(pwd)` | `/runner/project` | Project files (playbooks, roles) | `:Z` |
| `$(pwd)/reports` | `/runner/project/reports` | Report output | `:Z,rw` (read-write) |

**SELinux Labels (`:Z`)** - Required for Podman:
- `:Z` = private unshared label
- `:z` = shared label
- `,rw` = read-write (default is read-only)

**Docker** doesn't need `:Z` labels - omit them when using Docker.

## Troubleshooting

### Reports Not Generated

Ensure the reports directory exists:

```bash
mkdir -p reports
```

The helper script creates it automatically.

### Kubeconfig Not Found

Verify the kubeconfig path in the container:

```bash
podman run --rm -it \
  -v ~/.kube:/runner/.kube:Z \
  -e KUBECONFIG=/runner/.kube/kubeconfig \
  quay.io/ansible/creator-ee:latest \
  ls -la /runner/.kube
```

Override the kubeconfig path by editing `run-in-ee.sh` and changing `KUBECONFIG_PATH`, or set it as an environment variable:

```bash
KUBECONFIG_PATH=/runner/.kube/kubeconfig \
  ./run-in-ee.sh playbooks/pre_upgrade_check.yml
```

### Permission Denied on Volume Mounts

Add `:Z` for Podman (SELinux labeling):

```bash
-v ~/.kube:/runner/.kube:Z
```

For Docker, omit `:Z`:

```bash
-v ~/.kube:/runner/.kube
```

### Container Engine Not Running

```bash
# Podman (macOS)
podman machine start

# Docker
# Start Docker Desktop
```

### kubernetes.core Collection Not Found

The `creator-ee` image includes this collection. Verify:

```bash
podman run --rm quay.io/ansible/creator-ee:latest \
  ansible-galaxy collection list | grep kubernetes.core
```

Expected output:
```
kubernetes.core               3.1.0
```

## Alternative: Local Ansible (Not Recommended)

If you must run locally without containers:

```bash
# Install Ansible and collections
pip install ansible
ansible-galaxy collection install kubernetes.core

# Run playbook
ansible-playbook playbooks/pre_upgrade_check.yml
```

**Note**: Local execution may have different behavior than AAP due to different Python versions, collection versions, and dependencies.

<<<<<<< HEAD
## Helper Script Reference
=======
Ensure your kubeconfig has read access to:

- Nodes
- Pods, CSVs in AAP namespace
- Resources in database namespace
>>>>>>> origin/main

The `run-in-ee.sh` script accepts:

<<<<<<< HEAD
=======
Ensure metrics-server is running:

>>>>>>> origin/main
```bash
./run-in-ee.sh [playbook] [ansible-playbook-options]
```

<<<<<<< HEAD
Environment variables you can set:

=======
If metrics are unavailable, the role continues but metrics fields show
"N/A".

## chadsno2026 Cluster

For the chadsno2026 cluster specifically:

- **Kubeconfig**: `~/.kube/kubeconfig-noingress`
- **Context**: `admin`
- **AAP Namespace**: `ansible-automation-platform`
- **Database Namespace**: `edb-pg-demo`
- **Database Cluster**: `demo-pg` (cloud-native-postgresql)

Use the dedicated playbook:

>>>>>>> origin/main
```bash
# Use different execution environment image
EE_IMAGE=registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest \
  ./run-in-ee.sh playbooks/pre_upgrade_check.yml

# Use different kubeconfig path in container
KUBECONFIG_PATH=/runner/.kube/my-config \
  ./run-in-ee.sh playbooks/pre_upgrade_check.yml

# Use docker instead of podman
CONTAINER_ENGINE=docker \
  ./run-in-ee.sh playbooks/pre_upgrade_check.yml
```

## Interactive Container Shell

<<<<<<< HEAD
For debugging or exploration:

```bash
podman run --rm -it \
  -v ~/.kube:/runner/.kube:Z \
  -v $(pwd):/runner/project:Z \
  -e KUBECONFIG=/runner/.kube/kubeconfig \
  -w /runner/project \
  quay.io/ansible/creator-ee:latest \
  /bin/bash
```

Inside the container:

```bash
# Check mounted volumes
ls -la /runner/.kube
ls -la /runner/project

# Test kubectl
kubectl version --client
kubectl cluster-info

# Run playbook manually
ansible-playbook playbooks/pre_upgrade_check.yml --syntax-check
ansible-playbook playbooks/pre_upgrade_check.yml --check
```

## Documentation

- [Role Documentation](roles/aap_pre_upgrade_check/README.md) - Detailed role documentation
- [Contributing](CONTRIBUTING.md) - Development workflow and guidelines
- [Security](SECURITY.md) - Security policy and vulnerability reporting
- [Test Results](TEST-RESULTS.md) - Validation test results
- [Container Execution Tests](docs/TEST-CONTAINER-EXECUTION.md) - Container test validation

## Tested and Verified

✅ All container execution tests passing (2026-05-29):
- Syntax validation in container
- Check mode (dry-run) execution
- Ansible 2.16.3 with Python 3.12 in container
- kubernetes.core collection v3.1.0 available
- Volume mounts working (kubeconfig, project files, reports)
- Helper script functionality
- Direct podman/docker commands
- Multiple playbooks

See [docs/TEST-CONTAINER-EXECUTION.md](docs/TEST-CONTAINER-EXECUTION.md) for detailed test results.
=======
See [chadsno2026-status-report.md](chadsno2026-status-report.md) for a
detailed manual investigation report of the chadsno2026 cluster from
2026-05-29.
>>>>>>> origin/main

## License

Apache-2.0

## Author

Chad Ferman (cferman@redhat.com)
