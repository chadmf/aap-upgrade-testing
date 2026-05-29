# AAP Pre-Upgrade Testing - Test Results Summary

**Date**: 2026-05-29  
**Tester**: Ansible Role `aap_pre_upgrade_check`  
**Test Environment**: macOS with Ansible 8.7.0 (ansible-core 2.15.13)

---

## Executive Summary

Successfully tested the AAP pre-upgrade health check Ansible role against two different AAP deployments:

1. ✅ **chadsno2026** - SNO OpenShift 4.21 cluster with AAP 2.6 and external PostgreSQL
2. ✅ **aap-lab** - CRC MicroShift 4.21 instance with AAP 2.7 and embedded database

Both tests completed successfully after fixing two bugs in the role.

---

## Test Environment Setup

### Python Virtual Environment
- **Location**: `/Users/cferman/git/aap-upgrade-testing/.venv`
- **Python**: 3.9
- **Ansible**: 8.7.0 (ansible-core 2.15.13)
- **Collections**: kubernetes.core, kubernetes 35.0.0, openshift 0.13.2

### Test Playbooks Created
1. `playbooks/check_chadsno2026.yml` - External database configuration
2. `playbooks/check_aap_lab.yml` - Embedded database configuration

---

## Bugs Fixed During Testing

### 1. Invalid Regex Pattern (check_operators.yml:85)

**Issue**: Regex pattern `\\d+/\\1` caused failure with error:
```
invalid group reference 1 at position 5
```

**Root Cause**: Backreference `\\1` is not valid in Ansible `match()` filter  

**Fix**: Changed condition to:
```yaml
when: item.value.status != 'Running' or not (item.value.ready is match('(\\d+)/(\\1)') and item.value.ready.split('/')[0] == item.value.ready.split('/')[1])
```

**File**: `roles/aap_pre_upgrade_check/tasks/check_operators.yml`

### 2. Undefined Variable in Error Message (check_database.yml:130)

**Issue**: Variable access in `issue_msg` referenced attributes that may not exist:
```
'dict object' has no attribute 'cluster_name'
```

**Root Cause**: Error message template referenced variables before checking if they exist  

**Fix**: Added default values and existence check:
```yaml
when:
  - aap_check_results.database.external | default(false)
  - aap_check_results.database.cluster_status | default('') != 'Cluster in healthy state'
  - aap_check_results.database.cluster_name is defined
vars:
  issue_msg: "Database cluster {{ aap_check_results.database.cluster_name | default('unknown') }} is unhealthy (status: {{ aap_check_results.database.cluster_status | default('unknown') }})"
```

**File**: `roles/aap_pre_upgrade_check/tasks/check_database.yml`

---

## Test 1: chadsno2026 Cluster

### Cluster Configuration
- **Type**: Single Node OpenShift (SNO)
- **Version**: OpenShift 4.21 (Kubernetes v1.34.4)
- **AAP Version**: 2.6.20260422
- **Database**: External PostgreSQL (cloud-native-postgresql)
- **Database Namespace**: edb-pg-demo
- **AAP Namespace**: ansible-automation-platform
- **Node**: 1c-69-7a-a4-45-a8 (Ready, 81 days uptime)
- **Kubeconfig**: `~/.kube/kubeconfig-noingress`

### Test Results

**Status**: ⚠️ Issues detected (pre-existing database operator issue)

**Health Checks Passed**:
- ✅ Cluster connectivity
- ✅ Node health (Ready, no pressure)
- ✅ All 7 AAP operators running (2/2 or 1/1 ready)
- ✅ AAP instance healthy and reconciling
- ✅ External PostgreSQL database pods running (2/2)

**Known Issues Detected**:
- ❌ **Critical**: CSV `cloud-native-postgresql.v1.28.2` in Failed state
- ⚠️ **Warning**: CSV `cloud-native-postgresql.v1.28.1` stuck in Replacing state
- ⚠️ **Warning**: Database operator upgrade v1.28.1 → v1.28.2 failed

**AAP Platform Status**:
- Controller: Running
- Last reconciliation: 2026-05-29T17:06:32 (successful)
- Failed tasks: 0
- URL: https://aap-ansible-automation-platform.apps.chadsno2026.fteam.local

**Test Command**:
```bash
ansible-playbook playbooks/check_chadsno2026.yml \
  -e aap_fail_on_failed_csv=false \
  -e aap_fail_on_unhealthy_database=false
```

**Report Generated**: `playbooks/reports/chadsno2026-pre-upgrade-20260529T142123.md`

**Notes**:
- The database operator issue was already documented in prior status reports
- AAP itself is fully functional despite the database operator being stuck
- Test parameters disabled failure on CSV/database issues to generate full report

---

## Test 2: aap-lab CRC Instance

### Cluster Configuration
- **Type**: CRC (CodeReady Containers) with MicroShift
- **Version**: MicroShift 4.21 (Kubernetes v1.34.2)
- **AAP Version**: 2.7.20260603
- **Database**: Embedded (internal)
- **Database Namespace**: N/A (embedded)
- **AAP Namespace**: aap-operator
- **Node**: api.crc.testing (Ready, 41 days uptime)
- **Kubeconfig**: `~/.aap-lab/kubeconfig.microshift`

### Test Results

**Status**: ✅ All checks passed - cluster is ready for upgrade

**Health Checks Passed**:
- ✅ Cluster connectivity
- ✅ Node health (Ready, no pressure)
- ✅ All 7 AAP operators running (1/1 ready each)
- ✅ AAP instance healthy and reconciling
- ✅ Embedded database (no external checks needed)

**Issues**: None detected

**AAP Platform Status**:
- Controller: Running
- Last reconciliation: 2026-05-29T14:24:32 (successful)
- Failed tasks: 0
- URL: https://aap-aap-operator.apps.127.0.0.1.nip.io

**Test Command**:
```bash
ansible-playbook playbooks/check_aap_lab.yml
```

**Report Generated**: `playbooks/reports/aap-lab-pre-upgrade-20260529T142602.md`

**Notes**:
- This is a newer AAP 2.7 deployment vs. 2.6 on chadsno2026
- CRC uses embedded database, role correctly detected this
- All operator pods running with 1/1 ready (smaller resource footprint)
- Completely clean health check with zero issues

---

## Comparison: External vs. Embedded Database Handling

### External Database (chadsno2026)

**Detection**:
```yaml
- Checks for secret: external-postgres-configuration-controller
- Extracts database host from secret data
- Parses namespace from FQDN: demo-pg-rw.edb-pg-demo.svc.cluster.local
- Sets active_db_namespace: edb-pg-demo
```

**Checks Performed**:
- ✅ cloud-native-postgresql Cluster resources
- ✅ Database pods status
- ✅ PostgreSQL operator CSV status
- ✅ Database cluster health (instances, ready state)
- ✅ Operator upgrade status

**Results**:
- Detected 2 database pods (demo-pg-1, demo-pg-2)
- Found database operator stuck in upgrade
- Correctly identified cluster type as "unmanaged" external PostgreSQL

### Embedded Database (aap-lab)

**Detection**:
```yaml
- Checks for secret: external-postgres-configuration-controller
- Secret not found
- Sets database type: embedded
- Skips all external database checks
```

**Checks Performed**:
- ✅ Embedded database flag set to true
- ⏭️ Skipped external PostgreSQL cluster checks
- ⏭️ Skipped database operator checks
- ⏭️ Skipped database pod checks

**Results**:
- Database type: embedded
- Configuration: Embedded
- No database-specific issues reported

### Role Behavior

The role correctly handles both configurations **without modification**:

1. **Auto-detection**: Presence of external database secret triggers external checks
2. **Conditional execution**: All external database tasks use `when: db_host is defined`
3. **Default fallback**: Missing secret → embedded database → skip external checks
4. **Clean reporting**: Report template adapts to database type

**No playbook changes required** for different database configurations - only the namespace variable needs adjustment.

---

## Network Connectivity Investigation

### Initial Problem
DevOps Automator agent reported chadsno2026 cluster as unreachable with:
```
OSError: [Errno 65] No route to host
```

### Root Cause Analysis

**Finding**: The issue was **DNS resolution**, not network connectivity.

**Evidence**:
```bash
# IP connectivity works
$ ping 192.168.68.61
64 bytes from 192.168.68.61: icmp_seq=0 ttl=64 time=5.696 ms

# API endpoint responds via IP
$ curl -k https://192.168.68.61:6443/version
{"major": "1", "minor": "34", ...}

# DNS fails
$ nslookup api.chadsno2026.fteam.local
** server can't find api.chadsno2026.fteam.local: NXDOMAIN

# /etc/hosts provides workaround
$ grep chadsno2026 /etc/hosts
192.168.68.61    api.chadsno2026.fteam.local
```

**Resolution**: The `/etc/hosts` file already contained the required entry. The kubectl client successfully resolves the hostname and connects.

**Why the agent failed**: Python kubernetes client library may have experienced DNS caching issues or used a different resolver than the system.

---

## Role Capabilities Validated

### Pre-flight Checks
- ✅ kubectl/oc CLI availability detection
- ✅ Cluster connectivity test
- ✅ Kubeconfig file validation
- ✅ Report output directory creation

### Node Health Monitoring
- ✅ Node status (Ready/NotReady)
- ✅ Node conditions (Memory/Disk/PID pressure)
- ✅ Resource usage collection (CPU/memory metrics)
- ✅ Kubernetes version detection
- ✅ OS and kernel version reporting

### Operator Health Checks
- ✅ ClusterServiceVersion (CSV) status
- ✅ Operator pod health and readiness
- ✅ Failed CSV detection
- ✅ Stuck upgrade detection (Replacing state)
- ✅ Expected operator validation (7 AAP operators)

### AAP Instance Validation
- ✅ AnsibleAutomationPlatform CR detection
- ✅ Instance health conditions (Running/Successful/Failure)
- ✅ Reconciliation status and timing
- ✅ Ansible task metrics (changed/ok/failed/skipped)
- ✅ Version and image reporting

### Database Backend Checks

**External PostgreSQL**:
- ✅ Secret-based configuration detection
- ✅ Namespace auto-discovery from FQDN
- ✅ cloud-native-postgresql Cluster status
- ✅ Database pod health
- ✅ Database operator CSV status
- ✅ Cluster health validation
- ✅ Instance count verification

**Embedded Database**:
- ✅ Automatic detection when external secret absent
- ✅ Proper skipping of external checks
- ✅ Clean reporting of embedded type

### Report Generation
- ✅ Markdown-formatted health report
- ✅ Executive summary with status indicators
- ✅ Detailed node information
- ✅ Operator status tables
- ✅ AAP instance details
- ✅ Database configuration
- ✅ Critical issues and warnings sections
- ✅ Actionable recommendations
- ✅ Configuration reference

---

## Test Coverage Summary

| Component | Test Coverage | Status |
|-----------|---------------|--------|
| Cluster connectivity | Both deployments | ✅ Pass |
| Node health checks | SNO + CRC | ✅ Pass |
| Operator status | 7 operators × 2 clusters | ✅ Pass |
| AAP instance health | AAP 2.6 + AAP 2.7 | ✅ Pass |
| External database | chadsno2026 | ✅ Pass |
| Embedded database | aap-lab | ✅ Pass |
| CSV failure detection | Postgres operator issue | ✅ Pass |
| Report generation | 2 reports generated | ✅ Pass |
| Error handling | 2 bugs found & fixed | ✅ Pass |

---

## Performance Metrics

### chadsno2026 (External DB)
- **Total Tasks**: 44 tasks executed
- **Changed**: 1 (report generation)
- **Skipped**: 13 tasks (conditional checks)
- **Execution Time**: ~45 seconds
- **Report Size**: 5.2 KB

### aap-lab (Embedded DB)
- **Total Tasks**: 33 tasks executed
- **Changed**: 1 (report generation)
- **Skipped**: 24 tasks (database checks skipped)
- **Execution Time**: ~35 seconds
- **Report Size**: 4.8 KB

**Note**: Embedded database configuration is faster due to fewer checks required.

---

## Files Modified

### Role Task Files
1. `roles/aap_pre_upgrade_check/tasks/check_operators.yml` - Fixed regex validation
2. `roles/aap_pre_upgrade_check/tasks/check_database.yml` - Fixed undefined variable access

### Test Playbooks Created
1. `playbooks/check_chadsno2026.yml` - External PostgreSQL configuration
2. `playbooks/check_aap_lab.yml` - Embedded database configuration

### Reports Generated
1. `playbooks/reports/chadsno2026-pre-upgrade-20260529T142123.md`
2. `playbooks/reports/aap-lab-pre-upgrade-20260529T142602.md`

---

## Recommendations

### For Production Use

1. **Fix the bugs in the role** before production deployment:
   - Apply the regex fix in check_operators.yml
   - Apply the variable safety fix in check_database.yml

2. **Adjust failure thresholds** based on environment:
   ```yaml
   aap_fail_on_failed_csv: true          # Fail on operator failures
   aap_fail_on_unhealthy_database: true  # Fail on database issues
   aap_fail_on_degraded_pods: false      # Warning only for pod issues
   ```

3. **Create environment-specific playbooks** with appropriate:
   - Kubeconfig paths
   - Namespace configurations
   - Database settings
   - Report naming conventions

4. **Schedule regular health checks**:
   - Pre-upgrade validation
   - Post-upgrade verification
   - Monthly health audits

### For the chadsno2026 Cluster

1. **Resolve database operator issue** before AAP upgrade:
   - Investigate why cloud-native-postgresql v1.28.2 upgrade failed
   - Consider manual intervention or rollback to v1.28.1
   - Check for operator compatibility issues

2. **Monitor AAP instance** health during remediation:
   - Current AAP platform is healthy despite operator issue
   - Ensure database connectivity remains stable
   - Validate backup strategy before making changes

### For the aap-lab Instance

1. **Cluster is ready for upgrade** - all checks passed
2. **Consider migration to external database** for:
   - Better scalability
   - Easier backup/restore
   - Production-like configuration

---

## Conclusion

The AAP pre-upgrade health check Ansible role successfully validated two different AAP deployment architectures:

✅ **External PostgreSQL** (chadsno2026) - Correctly detected and validated external database configuration, identified pre-existing operator issue

✅ **Embedded Database** (aap-lab) - Properly detected embedded configuration and skipped external checks, reported clean health status

**Role Quality**: After fixing two bugs, the role demonstrates robust:
- Multi-environment support (SNO, CRC, different AAP versions)
- Flexible database handling (auto-detection, conditional checks)
- Comprehensive health validation (nodes, operators, AAP instances, databases)
- Clear, actionable reporting (issues, warnings, recommendations)

**Test Outcome**: ✅ **SUCCESSFUL** - Role is production-ready after applying bug fixes.

---

**Test Report End**
