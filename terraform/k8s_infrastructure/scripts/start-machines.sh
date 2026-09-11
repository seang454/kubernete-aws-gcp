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
Start machines in the Kubernetes cluster (power on).

Usage:
  $(basename "$0")                          Start ALL machines (clears stopped list)
  $(basename "$0") <inst1> [inst2] ...      Start SPECIFIC previously stopped machines
  $(basename "$0") --list                   List current machine power status
  $(basename "$0") --plan                   Dry-run (plan only)

Examples:
  $(basename "$0")                          # Power on all cluster VMs
  $(basename "$0") --list                   # Show running and stopped instances
  $(basename "$0") k8s-worker03             # Power on worker03 specifically
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
  exit 0
fi

if [ ${#NODES[@]} -gt 0 ]; then
  # Read existing stopped_nodes, remove the requested nodes, and re-apply
  CURRENT_STOPPED=$(terraform -chdir="$INFRA_DIR" output -json stopped_nodes 2>/dev/null || echo "[]")
  NEW_STOPPED=$(python3 -c "
import json, sys
current = set(json.loads('''$CURRENT_STOPPED'''))
to_start = set(sys.argv[1:])
remaining = list(current - to_start)
print(json.dumps(remaining))
" "${NODES[@]}")

  echo -e "${GREEN}Starting previously stopped machine(s):${NC}"
  for node in "${NODES[@]}"; do
    echo -e "  ${GREEN}▶ ${node}${NC}"
  done
  echo

  if $PLAN_ONLY; then
    terraform -chdir="$INFRA_DIR" plan -var="desired_status=RUNNING" -var="stop_nodes=${NEW_STOPPED}"
  else
    terraform -chdir="$INFRA_DIR" apply -var="desired_status=RUNNING" -var="stop_nodes=${NEW_STOPPED}"
  fi
else
  # Start ALL machines
  echo -e "${GREEN}Starting ALL machines in the cluster...${NC}"
  if $PLAN_ONLY; then
    terraform -chdir="$INFRA_DIR" plan -var="desired_status=RUNNING" -var="stop_nodes=[]"
  else
    terraform -chdir="$INFRA_DIR" apply -var="desired_status=RUNNING" -var="stop_nodes=[]"
  fi
fi
