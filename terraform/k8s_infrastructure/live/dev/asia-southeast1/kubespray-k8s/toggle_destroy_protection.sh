#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/../../../../modules"

GCP_FILE="${MODULES_DIR}/gcp-kubespray-cluster/main.tf"
AWS_FILE="${MODULES_DIR}/aws-kubespray-workers/main.tf"
DO_FILE="${MODULES_DIR}/digitalocean-kubespray-cluster/main.tf"

ACTION="${1:-status}"

python3 - <<EOF
import re
import sys

action = "$ACTION"

configs = [
    {
        "name": "gcp-kubespray-cluster",
        "file": "$GCP_FILE",
        "resource": "google_compute_instance",
    },
    {
        "name": "aws-kubespray-workers",
        "file": "$AWS_FILE",
        "resource": "aws_instance",
    },
    {
        "name": "digitalocean-kubespray-cluster",
        "file": "$DO_FILE",
        "resource": "digitalocean_droplet",
    }
]

if action in ["enable", "on", "lock"]:
    print("🔒 Enabling destroy protection (prevent_destroy = true) on all VM instances...")
    for c in configs:
        with open(c["file"], "r") as f:
            content = f.read()
        # Look for resource block and update its prevent_destroy
        pattern = rf'(resource\s+"{c["resource"]}"\s+"this"\s+{{[\s\S]*?lifecycle\s+{{[\s\S]*?prevent_destroy\s*=\s*)(false|true)'
        new_content = re.sub(pattern, r'\g<1>true', content)
        with open(c["file"], "w") as f:
            f.write(new_content)
        print(f"  ✔ Locked: {c['name']} ({c['resource']})")
    print("✅ All cloud VM instances are now LOCKED against destruction.")

elif action in ["disable", "off", "unlock"]:
    print("🔓 Disabling destroy protection (prevent_destroy = false) on all VM instances...")
    for c in configs:
        with open(c["file"], "r") as f:
            content = f.read()
        pattern = rf'(resource\s+"{c["resource"]}"\s+"this"\s+{{[\s\S]*?lifecycle\s+{{[\s\S]*?prevent_destroy\s*=\s*)(false|true)'
        new_content = re.sub(pattern, r'\g<1>false', content)
        with open(c["file"], "w") as f:
            f.write(new_content)
        print(f"  ✔ Unlocked: {c['name']} ({c['resource']})")
    print("⚠️ Destruction UNLOCKED. You may now run 'terraform destroy'.")

elif action == "status":
    print("🔍 VM Destroy Protection Status:")
    for c in configs:
        with open(c["file"], "r") as f:
            content = f.read()
        pattern = rf'resource\s+"{c["resource"]}"\s+"this"\s+{{[\s\S]*?lifecycle\s+{{[\s\S]*?prevent_destroy\s*=\s*(false|true)'
        match = re.search(pattern, content)
        if match:
            state = match.group(1)
            icon = "🔒" if state == "true" else "⚠️"
            status_text = "PROTECTED (prevent_destroy = true)" if state == "true" else "UNLOCKED (prevent_destroy = false)"
            print(f"  {icon} {c['name']}: {status_text}")
        else:
            print(f"  ❓ {c['name']}: Not found")
else:
    print("Usage: ./toggle_destroy_protection.sh {enable|disable|status}")
    sys.exit(1)
EOF
