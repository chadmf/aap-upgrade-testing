#!/usr/bin/env bash
# run-in-ee.sh - Run Ansible playbook in execution environment container
#
# Usage:
#   ./run-in-ee.sh [playbook] [ansible-playbook-args...]
#
# Examples:
#   ./run-in-ee.sh playbooks/pre_upgrade_check.yml
#   ./run-in-ee.sh playbooks/pre_upgrade_check.yml --tags operators
#   ./run-in-ee.sh playbooks/pre_upgrade_check.yml -e aap_namespace=my-ns
#   ./run-in-ee.sh playbooks/pre_upgrade_check.yml --check

set -euo pipefail

# Default playbook if not provided
PLAYBOOK="${1:-playbooks/pre_upgrade_check.yml}"
shift || true

# Container image
EE_IMAGE="${EE_IMAGE:-quay.io/ansible/creator-ee:latest}"

# Kubeconfig path in container
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/runner/.kube/kubeconfig}"

# Container engine (podman or docker)
CONTAINER_ENGINE="${CONTAINER_ENGINE:-podman}"

# Ensure reports directory exists
mkdir -p reports

echo "Running playbook in execution environment..."
echo "  Playbook: $PLAYBOOK"
echo "  EE Image: $EE_IMAGE"
echo "  Kubeconfig: $KUBECONFIG_PATH"
echo ""

# Run the playbook in the execution environment
# Note: Disable -it flags if not in a TTY (fixes automation/CI)
TTY_FLAGS="-it"
if [ ! -t 0 ]; then
    TTY_FLAGS=""
fi

$CONTAINER_ENGINE run --rm $TTY_FLAGS \
  --name aap-upgrade-check-$$ \
  -v ~/.kube:/runner/.kube:Z \
  -v "$(pwd)":/runner/project:Z \
  -v "$(pwd)"/reports:/runner/project/reports:Z,rw \
  -e KUBECONFIG="$KUBECONFIG_PATH" \
  -e ANSIBLE_STDOUT_CALLBACK=default \
  -w /runner/project \
  "$EE_IMAGE" \
  ansible-playbook "$PLAYBOOK" "$@"
