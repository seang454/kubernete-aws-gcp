#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../live/dev/asia-southeast1/kubespray-k8s" && pwd)"

echo "Starting VMs created by Terraform in:"
echo "  $INFRA_DIR"
echo

terraform -chdir="$INFRA_DIR" init
terraform -chdir="$INFRA_DIR" apply -var="desired_status=RUNNING" "$@"
