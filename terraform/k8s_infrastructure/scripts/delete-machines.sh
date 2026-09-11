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
Delete specific machines from the Kubernetes cluster.

Usage:
  $(basename "$0") <instance1> [instance2] ...     Delete specific nodes
  $(basename "$0") --list                           List all instance names
  $(basename "$0") --plan <instance1> [instance2]   Dry-run (plan only)

Examples:
  $(basename "$0") --list
  $(basename "$0") --plan k8s-haproxy-1 k8s-haproxy-2
  $(basename "$0") k8s-haproxy-1 k8s-haproxy-2 k8s-worker01 k8s-master02

Instance names use the full GCP name with prefix: k8s-master01, k8s-worker01, k8s-haproxy-1, etc.
EOF
  exit 1
}

# --- Parse arguments -------------------------------------------------------
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

# --- Init ------------------------------------------------------------------
terraform -chdir="$INFRA_DIR" init -input=false > /dev/null 2>&1

# --- List mode -------------------------------------------------------------
if $LIST_ONLY; then
  echo -e "${CYAN}All GCP instance names defined in Terraform:${NC}"
  echo
  terraform -chdir="$INFRA_DIR" output -json machine_plan 2>/dev/null \
    | python3 -c "
import json, sys
nodes = json.load(sys.stdin)
for n in nodes:
    print(f\"  {n['role']:<14s}  {n['instance_name']}\")
" 2>/dev/null || echo "  (run 'terraform apply' first to see instance names)"
  echo
  echo -e "Currently excluded:"
  terraform -chdir="$INFRA_DIR" output -json excluded_nodes 2>/dev/null \
    | python3 -c "
import json, sys
excluded = json.load(sys.stdin)
if excluded:
    for n in excluded:
        print(f'  - {n}')
else:
    print('  (none)')
" 2>/dev/null || echo "  (not available)"
  exit 0
fi

# --- Validate arguments ----------------------------------------------------
if [ ${#NODES[@]} -eq 0 ]; then
  echo -e "${RED}Error: No instance names specified.${NC}"
  echo
  usage
fi

# Build the Terraform list value
TF_LIST=$(printf '"%s",' "${NODES[@]}")
TF_LIST="[${TF_LIST%,}]"

echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  WARNING: This will PERMANENTLY DELETE the following    ║${NC}"
echo -e "${YELLOW}║  machines and all their associated resources (VM, IP,   ║${NC}"
echo -e "${YELLOW}║  disks). This action cannot be undone.                  ║${NC}"
echo -e "${YELLOW}╠══════════════════════════════════════════════════════════╣${NC}"
for node in "${NODES[@]}"; do
  printf "${YELLOW}║${NC}  ${RED}✗ %-54s${NC}${YELLOW}║${NC}\n" "$node"
done
echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# --- Plan / Apply ----------------------------------------------------------
if $PLAN_ONLY; then
  echo -e "${CYAN}Running terraform plan (dry-run)...${NC}"
  echo
  terraform -chdir="$INFRA_DIR" plan -var="exclude_nodes=${TF_LIST}"
else
  echo -e "${CYAN}Running terraform apply...${NC}"
  echo
  terraform -chdir="$INFRA_DIR" apply -var="exclude_nodes=${TF_LIST}"
fi
