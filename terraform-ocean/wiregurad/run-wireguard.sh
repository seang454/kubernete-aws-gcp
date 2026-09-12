#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

INVENTORY="inventory/hosts.ini"

if [ ! -f "$INVENTORY" ]; then
  echo "❌ Inventory file '$INVENTORY' not found."
  echo "   Please run 'terraform apply' in terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s"
  echo "   to generate the inventory with the real VM public IPs."
  exit 1
fi

ACTION="${1:-deploy}"

case "$ACTION" in
  verify|check|test)
    shift || true
    echo "================================================================="
    echo " Verifying WireGuard Full Mesh Handshakes and Ping"
    echo "================================================================="
    ansible-playbook -i "$INVENTORY" verify.yml "$@"
    ;;
  *)
    echo "================================================================="
    echo " Deploying WireGuard Full Mesh across all 7 nodes (GCP + AWS)"
    echo "================================================================="
    ansible-playbook -i "$INVENTORY" site.yml "$@"
    ;;
esac
