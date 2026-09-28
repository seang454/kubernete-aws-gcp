#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../live/dev/asia-southeast1/gcp-vm" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANSIBLE_DIR="$PROJECT_DIR/jenkins-cac"

PLAYBOOK="${1:-playbooks/site.yml}"
INVENTORY="${ANSIBLE_INVENTORY:-inventories/dev/hosts.ini}"

echo "Terraform root:"
echo "  $INFRA_DIR"
echo

terraform -chdir="$INFRA_DIR" init -reconfigure -backend-config=backend.gcs.hcl
terraform -chdir="$INFRA_DIR" apply

echo
echo "Terraform completed."
terraform -chdir="$INFRA_DIR" output ansible_inventory_path || true
terraform -chdir="$INFRA_DIR" output cloudflare_hostnames || true
echo

read -r -p "Run Ansible now with ${PLAYBOOK}? [y/N] " answer

case "${answer}" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Stopped after Terraform. Ansible was not run."
    exit 0
    ;;
esac

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ansible-playbook was not found. Install Ansible in this shell/WSL environment first."
  exit 1
fi

cd "$ANSIBLE_DIR"

if command -v ansible-galaxy >/dev/null 2>&1; then
  ansible-galaxy collection install -r collections/requirements.yml
fi

ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
