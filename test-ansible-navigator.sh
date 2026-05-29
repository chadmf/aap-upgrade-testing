#!/usr/bin/env bash
# Test script for ansible-navigator execution environment setup
# This validates that ansible-navigator can run the AAP upgrade testing playbooks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test function
run_test() {
    local test_name=$1
    shift
    ((TESTS_RUN++))

    log_info "Test $TESTS_RUN: $test_name"

    if "$@"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Test functions
test_ansible_navigator_installed() {
    command -v ansible-navigator >/dev/null 2>&1
}

test_container_engine_available() {
    if command -v podman >/dev/null 2>&1; then
        log_info "Using Podman"
        return 0
    elif command -v docker >/dev/null 2>&1; then
        log_info "Using Docker"
        return 0
    else
        return 1
    fi
}

test_container_engine_running() {
    if command -v podman >/dev/null 2>&1; then
        podman info >/dev/null 2>&1
    elif command -v docker >/dev/null 2>&1; then
        docker info >/dev/null 2>&1
    else
        return 1
    fi
}

test_ee_image_available() {
    local image="quay.io/ansible/creator-ee:latest"

    if command -v podman >/dev/null 2>&1; then
        podman image exists "$image" 2>/dev/null
    elif command -v docker >/dev/null 2>&1; then
        docker image inspect "$image" >/dev/null 2>&1
    else
        return 1
    fi
}

test_ansible_navigator_config_exists() {
    [[ -f ansible-navigator.yml ]]
}

test_kubeconfig_accessible() {
    [[ -f ~/.kube/kubeconfig-noingress ]] || [[ -f ~/.kube/config ]]
}

test_inventory_exists() {
    [[ -f inventory ]]
}

test_navigator_can_mount_volumes() {
    # Test if navigator can access project files
    ansible-navigator exec -- ls /runner/project/playbooks >/dev/null 2>&1
}

test_navigator_ansible_version() {
    # Check that the EE has Ansible installed
    ansible-navigator exec -- ansible --version >/dev/null 2>&1
}

test_navigator_has_kubernetes_core() {
    # Check that kubernetes.core collection is available in the EE
    ansible-navigator exec -- ansible-galaxy collection list 2>/dev/null | \
        grep -q "kubernetes.core" || \
        ansible-navigator collections --mode stdout 2>/dev/null | \
        grep -q "kubernetes.core"
}

pull_ee_image() {
    local image="quay.io/ansible/creator-ee:latest"

    log_info "Pulling execution environment image..."

    if command -v podman >/dev/null 2>&1; then
        podman pull "$image"
    elif command -v docker >/dev/null 2>&1; then
        docker pull "$image"
    else
        log_error "No container engine available"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "ansible-navigator Test Suite"
    echo "AAP Upgrade Testing Project"
    echo "=========================================="
    echo ""

    # Pre-flight checks
    log_info "Running pre-flight checks..."

    run_test "ansible-navigator is installed" test_ansible_navigator_installed || {
        log_error "ansible-navigator not found. Install with: pip install ansible-navigator"
        exit 1
    }

    run_test "Container engine is available" test_container_engine_available || {
        log_error "No container engine found. Install podman or docker."
        exit 1
    }

    run_test "Container engine is running" test_container_engine_running || {
        log_error "Container engine not running. Start with: podman machine start"
        exit 1
    }

    # Check for EE image
    if ! test_ee_image_available; then
        log_warning "Execution environment image not found locally"
        if ! pull_ee_image; then
            log_error "Failed to pull execution environment image"
            exit 1
        fi
        run_test "Execution environment image is available" test_ee_image_available
    else
        run_test "Execution environment image is available" test_ee_image_available
    fi

    echo ""
    log_info "Running configuration checks..."

    run_test "ansible-navigator.yml exists" test_ansible_navigator_config_exists
    run_test "Kubeconfig is accessible" test_kubeconfig_accessible || {
        log_warning "Kubeconfig not found at ~/.kube/kubeconfig-noingress or ~/.kube/config"
        log_warning "Playbook execution will fail without valid kubeconfig"
    }
    run_test "Inventory file exists" test_inventory_exists

    echo ""
    log_info "Running ansible-navigator functionality tests..."

    run_test "Playbook syntax is valid" test_playbook_syntax_check || {
        log_warning "Syntax check failed - this might be due to missing kubeconfig in container"
    }

    run_test "Container can access Ansible" test_navigator_ansible_version || {
        log_warning "Could not verify Ansible version in container"
    }

    run_test "kubernetes.core collection is available" test_navigator_has_kubernetes_core || {
        log_warning "kubernetes.core collection check failed"
        log_warning "Collection might still be available but not detectable via this test"
    }

    run_test "Volume mounts are working" test_navigator_can_mount_volumes || {
        log_warning "Volume mount test failed - check ansible-navigator.yml configuration"
    }

    echo ""
    log_info "Running integration test (dry-run)..."

    run_test "Playbook dry-run (check mode, preflight only)" test_dry_run_playbook || {
        log_warning "Dry-run test failed - check logs at /tmp/navigator-test.log"
        log_warning "This may fail if kubeconfig/cluster access is not configured"
    }

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total Tests: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        echo "All tests passed!"
        exit 0
    else
        log_error "Some tests failed. Review the output above."
        echo ""
        log_info "Common fixes:"
        echo "  - Install missing tools: pip install ansible-navigator"
        echo "  - Start container engine: podman machine start"
        echo "  - Pull EE image: podman pull quay.io/ansible/creator-ee:latest"
        echo "  - Configure kubeconfig: export KUBECONFIG=~/.kube/config"
        exit 1
    fi
}

# Run main function
main "$@"
