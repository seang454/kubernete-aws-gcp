#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

terraform -chdir="$ROOT_DIR" fmt -check -recursive

for component in \
  "$ROOT_DIR/live/dev/asia-southeast1/gcp-vm"
do
  echo "Validating $component"
  cd "$component"
  terraform init
  terraform validate
done
