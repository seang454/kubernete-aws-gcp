#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for component in \
  "$ROOT_DIR/live/dev/asia-southeast1/kubespray-k8s"
do
  echo "Planning $component"
  cd "$component"
  terraform init
  terraform plan
done
