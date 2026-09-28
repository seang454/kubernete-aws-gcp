#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for component in \
  "$ROOT_DIR/live/dev/asia-southeast1/gcp-vm"
do
  echo "Planning $component"
  cd "$component"
  terraform init
  terraform plan
done
