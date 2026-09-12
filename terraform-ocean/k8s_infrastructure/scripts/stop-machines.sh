#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../live/dev/asia-southeast1/kubespray-k8s" && pwd)"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

usage() {
  cat <<EOF
Stop machines in the Kubernetes cluster (power off without deleting VM, disks, or IP).

Usage:
  $(basename "$0")                          Stop ALL machines in the cluster
  $(basename "$0") <inst1> [inst2] ...      Stop SPECIFIC machines
  $(basename "$0") --list                   List all instances and current status
  $(basename "$0") --plan [inst1] [inst2]   Dry-run (plan only)

Examples:
  $(basename "$0")                          # Stop all cluster VMs
  $(basename "$0") --list                   # Show all running and stopped instances
  $(basename "$0") k8s-worker03 k8s-worker04 # Stop worker03 and worker04 only
  $(basename "$0") --plan k8s-worker02       # Plan stopping worker02

To start machines back up, run ./scripts/start-machines.sh.
EOF
  exit 1
}

PLAN_ONLY=false
LIST_ONLY=false
NODES=()

for arg in "$@"; do
  case "$arg" in
    --list)    LIST_ONLY=true ;;
    --plan)    PLAN_ONLY=true ;;
    --help|-h) usage ;;
    -*)        echo "Unknown option: $arg"; usage ;;
    *)         NODES+=("$arg") ;;
  esac
done

terraform -chdir="$INFRA_DIR" init -input=false > /dev/null 2>&1

if $LIST_ONLY; then
  echo -e "${CYAN}All instance names defined in Terraform:${NC}"
  echo
  terraform -chdir="$INFRA_DIR" output -json machine_plan 2>/dev/null \
    | python3 -c "
import json, sys
nodes = json.load(sys.stdin)
for n in nodes:
    cloud = n.get('cloud', 'gcp').upper()
    print(f\"  {n['role']:<14s}  {n['instance_name']:<20s}  [{cloud}]\")
" 2>/dev/null || echo "  (run 'terraform apply' first to see instance names)"
  echo
  echo -e "${YELLOW}Currently stopped (powered off):${NC}"
  terraform -chdir="$INFRA_DIR" output -json stopped_nodes 2>/dev/null \
    | python3 -c "
import json, sys
stopped = json.load(sys.stdin)
if stopped:
    for n in stopped:
        print(f'  - {n}')
else:
    print('  (none - all active nodes running)')
" 2>/dev/null || echo "  (none)"
  echo
  echo -e "${RED}Currently excluded (deleted):${NC}"
  terraform -chdir="$INFRA_DIR" output -json excluded_nodes 2>/dev/null \
    | python3 -c "
import json, sys
excluded = json.load(sys.stdin)
if excluded:
    for n in excluded:
        print(f'  - {n}')
else:
    print('  (none)')
" 2>/dev/null || echo "  (none)"
  exit 0
fi

if [ ${#NODES[@]} -gt 0 ]; then
  # Stop specific machines
  TF_LIST=$(printf '"%s",' "${NODES[@]}")
  TF_LIST="[${TF_LIST%,}]"

  echo -e "${CYAN}Stopping the following specific machines (power off only):${NC}"
  for node in "${NODES[@]}"; do
    echo -e "  ${YELLOW}⏸ ${node}${NC}"
  done
  echo

  if $PLAN_ONLY; then
    terraform -chdir="$INFRA_DIR" plan -var="stop_nodes=${TF_LIST}"
  else
    terraform -chdir="$INFRA_DIR" apply -var="stop_nodes=${TF_LIST}"
  fi
else
  # Stop ALL machines
  echo -e "${YELLOW}Stopping ALL machines in the cluster (power off only)...${NC}"
  if $PLAN_ONLY; then
    terraform -chdir="$INFRA_DIR" plan -var="desired_status=TERMINATED"
  else
    terraform -chdir="$INFRA_DIR" apply -var="desired_status=TERMINATED"
  fi
fi
