# AAP on chadsno2026 - Status Report

**Date**: 2026-05-29  
**Cluster**: chadsno2026  
**Investigation Focus**: Node health, AAP operator status, and database backend verification

## Executive Summary

The chadsno2026 OpenShift cluster is operational with AAP 2.6 successfully deployed and running. However, a failed cloud-native-postgresql operator upgrade requires attention to ensure future database management operations function correctly.

## Node Status

**Node Details:**
- **Name**: `1c-69-7a-a4-45-a8`
- **Status**: Ready ✓
- **Roles**: control-plane, master, worker (single-node cluster)
- **Age**: 81 days
- **OpenShift Version**: v1.34.4 (OpenShift 4.21)
- **OS**: Red Hat Enterprise Linux CoreOS 9.6.20260311-0 (Plow)
- **Kernel**: 5.14.0-570.98.1.el9_6.x86_64
- **Container Runtime**: cri-o://1.34.6-2.rhaos4.21

**Network:**
- **Internal IP**: 192.168.68.61
- **External IP**: None

**Resource Usage:**
- **CPU**: 6092m / 52% of capacity
- **Memory**: 20677Mi / 67% of capacity

**Assessment**: Node is healthy with moderate resource utilization.

---

## AAP Operator Status

### Operator Installation

**ClusterServiceVersion (CSV):**
- **Name**: aap-operator.v2.6.0-0.1777410689
- **Display Name**: Ansible Automation Platform
- **Version**: 2.6.0+0.1777410689
- **Status**: Succeeded ✓
- **Replaces**: aap-operator.v2.6.0-0.1774648945

### Operator Pods

All AAP operator components are running in the `ansible-automation-platform` namespace:

| Operator | Pod Name | Status | Restarts | Age |
|----------|----------|--------|----------|-----|
| Gateway | aap-gateway-operator-controller-manager-765c597bd6-9br6j | 2/2 Running | 6 | 24d |
| Lightspeed | ansible-lightspeed-operator-controller-manager-b8bdbf57d-p2g2m | 2/2 Running | 6 | 24d |
| Controller | automation-controller-operator-controller-manager-5cd4bbb9vdvzw | 2/2 Running | 6 | 24d |
| Hub | automation-hub-operator-controller-manager-557b559b8b-b4chx | 2/2 Running | 6 | 24d |
| Metrics | automationmetricsservice-operator-controller-manager-59587pmnz8 | 1/1 Running | 6 | 24d |
| EDA Server | eda-server-operator-controller-manager-db49f958b-fclm9 | 2/2 Running | 6 | 24d |
| Resource | resource-operator-controller-manager-7994f5d7bf-jdcr2 | 2/2 Running | 6 | 24d |

**Note**: All operators restarted 3d17h ago (6 total restarts per pod).

### AAP Instance (Custom Resource)

**AnsibleAutomationPlatform CR:**
- **Name**: aap
- **Namespace**: ansible-automation-platform
- **Age**: 55 days
- **Version**: 2.6.20260422
- **URL**: https://aap-ansible-automation-platform.apps.chadsno2026.fteam.local
- **Admin User**: admin
- **Admin Password Secret**: aap-admin-password

**Reconciliation Status:**
- **Last Reconciliation**: 2026-05-29 07:04:29 UTC (today)
- **Status**: Successful ✓
- **Ansible Run Results**:
  - Changed: 4
  - OK: 135
  - Skipped: 178
  - Failures: 0

**Conditions:**
- **Running**: True (Awaiting next reconciliation)
- **Successful**: True (Last reconciliation succeeded)
- **Failure**: False

**Configuration Secrets:**
- Controller Database: `external-postgres-configuration-controller`
- Gateway Database: `external-postgres-configuration-gateway`
- Gateway Redis: `aap-gateway-redis-configuration`
- Gateway Settings: `aap-gateway-settings`
- DB Fields Encryption: `aap-db-fields-encryption-secret`

**Assessment**: AAP instance is fully operational and healthy.

---

## Database Backend Investigation

### Configuration

AAP is configured to use **external PostgreSQL** (not embedded database):

**Database Cluster:**
- **Type**: cloud-native-postgresql (EDB Postgres for Kubernetes)
- **Cluster Name**: demo-pg
- **Namespace**: edb-pg-demo
- **Host**: demo-pg-rw.edb-pg-demo.svc.cluster.local
- **Age**: 64 days

**Cluster Status:**
- **Instances**: 2
- **Ready Instances**: 2 ✓
- **Status**: Cluster in healthy state ✓
- **Primary**: demo-pg-1

**PostgreSQL Pods:**
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| demo-pg-1 | 1/1 Running | 4 | 64d |
| demo-pg-2 | 1/1 Running | 4 | 64d |

### Database Operator Issues ⚠️

The cloud-native-postgresql operator has encountered upgrade problems:

**Operator Versions:**
| Version | Status |
|---------|--------|
| v1.28.0 | Succeeded (replaced) |
| v1.28.1 | **Replacing** (stuck) |
| v1.28.2 | **Failed** |

**Issue Details:**
- Operator attempted to upgrade from v1.28.1 to v1.28.2
- v1.28.2 upgrade failed
- v1.28.1 is stuck in "Replacing" state

**Current Impact:**
- **Database cluster (demo-pg)**: ✓ Healthy and operational
- **AAP services**: ✓ Functioning normally
- **Database operator**: ⚠️ Stuck in upgrade cycle

**Risk Assessment:**
While the PostgreSQL cluster and AAP are currently healthy, the failed operator upgrade could impact:
- Future database scaling operations
- Automatic failover capabilities
- Database backup/restore operations
- Future operator-managed updates

---

## Recommendations

1. **Immediate Actions:**
   - Continue monitoring AAP services (currently healthy)
   - PostgreSQL cluster is stable; no immediate intervention required

2. **Database Operator Remediation (Priority: Medium):**
   - Investigate cloud-native-postgresql operator upgrade failure
   - Review operator logs: `kubectl logs -n ansible-automation-platform deployment/<operator-pod> -c manager`
   - Consider rollback to v1.28.0 if v1.28.1 is unstable
   - Document resolution steps for future upgrades

3. **Resource Monitoring:**
   - Node memory at 67% - plan for capacity if workload increases
   - Monitor CPU usage trends (currently 52%)

4. **Documentation:**
   - Document external PostgreSQL configuration
   - Maintain runbook for database operator issues
   - Record AAP upgrade path from current version (2.6.20260422)

---

## Configuration Reference

### Kubeconfig

**File**: `~/.kube/kubeconfig-noingress`  
**Context**: admin  
**Usage**: `KUBECONFIG=~/.kube/kubeconfig-noingress kubectl ...`

### Key Commands

```bash
# Node status
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl get nodes -o wide
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl top nodes

# AAP operator status
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl get csv -n ansible-automation-platform
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl get pods -n ansible-automation-platform
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl get ansibleautomationplatform -n ansible-automation-platform

# Database status
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl get cluster -n edb-pg-demo
KUBECONFIG=~/.kube/kubeconfig-noingress kubectl get pods -n edb-pg-demo
```

---

## Appendix: System Architecture

```
┌─────────────────────────────────────────────────┐
│           chadsno2026 OpenShift Node            │
│  (1c-69-7a-a4-45-a8 - 192.168.68.61)           │
│  OpenShift 4.21 / RHCOS 9.6                     │
└─────────────────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
┌───────────────────┐    ┌────────────────────────┐
│ Namespace:        │    │ Namespace:             │
│ ansible-          │    │ edb-pg-demo            │
│ automation-       │    │                        │
│ platform          │    │ ┌──────────────────┐   │
│                   │    │ │ demo-pg cluster  │   │
│ ┌───────────────┐ │    │ │ - demo-pg-1      │   │
│ │ AAP 2.6       │ │    │ │ - demo-pg-2      │   │
│ │ Instance      │◄┼────┤ │ (PostgreSQL HA)  │   │
│ │               │ │    │ └──────────────────┘   │
│ └───────────────┘ │    │                        │
│                   │    │ Managed by:            │
│ ┌───────────────┐ │    │ cloud-native-          │
│ │ 7 Operators:  │ │    │ postgresql v1.28.1     │
│ │ - Gateway     │ │    │ (upgrade stuck)        │
│ │ - Controller  │ │    │                        │
│ │ - Hub         │ │    └────────────────────────┘
│ │ - EDA         │ │
│ │ - Lightspeed  │ │
│ │ - Metrics     │ │
│ │ - Resource    │ │
│ └───────────────┘ │
└───────────────────┘
```

---

**Report Generated**: 2026-05-29  
**Investigation Tool**: Claude Code CLI  
**Cluster Access**: Via kubeconfig-noingress
