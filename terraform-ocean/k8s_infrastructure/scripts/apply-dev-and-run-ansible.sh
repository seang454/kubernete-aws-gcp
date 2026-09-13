#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../live/dev/asia-southeast1/kubespray-k8s" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WIREGUARD_DIR="$PROJECT_DIR/wiregurad"
KUBESPRAY_DIR="$PROJECT_DIR/ansible_kubespray_k8s/kubespray"

PLAYBOOK="${1:-cluster.yml}"
INVENTORY="${ANSIBLE_INVENTORY:-inventory/sample/inventory.ini}"

echo "================================================================="
echo " Step 1: Deploy Cloud Infrastructure with Terraform (GCP + AWS + DigitalOcean)"
echo "================================================================="
echo "Terraform root: $INFRA_DIR"
echo

terraform -chdir="$INFRA_DIR" init
terraform -chdir="$INFRA_DIR" apply

echo
echo "✅ Terraform completed."
terraform -chdir="$INFRA_DIR" output wireguard_inventory_path || true
terraform -chdir="$INFRA_DIR" output kubespray_inventory_path || true
echo

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ansible-playbook was not found. Install Ansible in this shell/WSL environment first."
  exit 1
fi

echo "================================================================="
echo " Step 2: Configure WireGuard Full-Mesh Tunnel (10.0.0.0/24)"
echo "================================================================="
read -r -p "Deploy WireGuard full mesh now? [y/N] " wg_answer

case "${wg_answer}" in
  y|Y|yes|YES)
    echo "Running WireGuard deployment..."
    "$WIREGUARD_DIR/run-wireguard.sh" deploy
    echo "Verifying WireGuard mesh connectivity..."
    "$WIREGUARD_DIR/run-wireguard.sh" verify
    echo "✅ WireGuard full mesh is operational."
    ;;
  *)
    echo "Skipped WireGuard deployment."
    ;;
esac

echo
echo "================================================================="
echo " Step 3: Install Kubernetes Cluster via Kubespray"
echo "================================================================="
read -r -p "Run Kubespray now with ${PLAYBOOK}? [y/N] " answer

case "${answer}" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Stopped after WireGuard. Kubespray was not run."
    exit 0
    ;;
esac

cd "$KUBESPRAY_DIR"

if command -v pip3 >/dev/null 2>&1 && [ -f requirements.txt ]; then
  pip3 install -r requirements.txt
fi

ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
