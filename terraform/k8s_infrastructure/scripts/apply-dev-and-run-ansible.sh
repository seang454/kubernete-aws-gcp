#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../live/dev/asia-southeast1/kubespray-k8s" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KUBESPRAY_DIR="$PROJECT_DIR/ansible_kubespray_k8s/kubespray"

PLAYBOOK="${1:-cluster.yml}"
INVENTORY="${ANSIBLE_INVENTORY:-inventory/sample/inventory.ini}"

echo "Terraform root:"
echo "  $INFRA_DIR"
echo

terraform -chdir="$INFRA_DIR" init
terraform -chdir="$INFRA_DIR" apply

echo
echo "Terraform completed."
terraform -chdir="$INFRA_DIR" output kubespray_inventory_path || true
echo

read -r -p "Run Kubespray now with ${PLAYBOOK}? [y/N] " answer

case "${answer}" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Stopped after Terraform. Kubespray was not run."
    exit 0
    ;;
esac

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ansible-playbook was not found. Install Ansible in this shell/WSL environment first."
  exit 1
fi

cd "$KUBESPRAY_DIR"

if command -v pip3 >/dev/null 2>&1 && [ -f requirements.txt ]; then
  pip3 install -r requirements.txt
fi

ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
