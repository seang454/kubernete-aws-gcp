# ---------------------------------------------------------------------------
# GCP In-Place Disk Resizer Module
#
# Resizes GCP Persistent Disks online using gcloud compute disks resize.
# Safe & zero-downtime: Does NOT destroy, replace, or restart VM instances.
# ---------------------------------------------------------------------------

resource "terraform_data" "resize_disk" {
  for_each = var.enabled ? var.disks : {}

  input = {
    disk_name      = each.value.disk_name
    zone           = each.value.zone
    target_size_gb = each.value.target_size_gb
  }

  triggers_replace = [
    each.value.target_size_gb,
    each.value.disk_name,
    each.value.zone
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      DISK_NAME="${each.value.disk_name}"
      ZONE="${each.value.zone}"
      TARGET_SIZE="${each.value.target_size_gb}"
      PROJECT_ID="${var.project_id}"

      if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
      fi

      echo "================================================================="
      echo " [GCP Disk Resizer] Checking disk: $DISK_NAME in zone: $ZONE"
      echo " Target Size: $${TARGET_SIZE}GB | Project: $PROJECT_ID"
      echo "================================================================="

      CURRENT_SIZE=$(gcloud compute disks describe "$DISK_NAME" \
        --zone="$ZONE" \
        --project="$PROJECT_ID" \
        --format="value(sizeGb)" 2>/dev/null || echo "")

      if [ -z "$CURRENT_SIZE" ]; then
        echo "WARNING: Disk '$DISK_NAME' not found in zone '$ZONE' (project '$PROJECT_ID'). Skipping."
      elif [ "$CURRENT_SIZE" -lt "$TARGET_SIZE" ]; then
        echo "--> Increasing disk $DISK_NAME from $${CURRENT_SIZE}GB to $${TARGET_SIZE}GB..."
        gcloud compute disks resize "$DISK_NAME" \
          --size="$${TARGET_SIZE}GB" \
          --zone="$ZONE" \
          --project="$PROJECT_ID" \
          --quiet
        echo "--> SUCCESS: Disk $DISK_NAME resized to $${TARGET_SIZE}GB in GCP."
      else
        echo "--> Disk $DISK_NAME is already $${CURRENT_SIZE}GB (>= target $${TARGET_SIZE}GB). No resize needed."
      fi

      echo "--> Verification:"
      gcloud compute disks describe "$DISK_NAME" \
        --zone="$ZONE" \
        --project="$PROJECT_ID" \
        --format="table(name,zone.basename():label=ZONE,sizeGb:label=SIZE_GB,type.basename():label=TYPE,status:label=STATUS)"
      echo "================================================================="
    EOT
  }
}

# Optional: Run Ansible disk expansion playbook to grow partitions and filesystems inside OS
resource "terraform_data" "ansible_expand" {
  count = var.enabled && var.auto_expand_filesystem && length(var.disks) > 0 ? 1 : 0

  input = {
    disks_signature = join(",", [for k, v in var.disks : "${v.disk_name}:${v.target_size_gb}"])
    inventory_path  = var.ansible_inventory_path
    playbook_path   = var.ansible_playbook_path
  }

  triggers_replace = [
    join(",", [for k, v in var.disks : "${v.disk_name}:${v.target_size_gb}"])
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      if [ -f "${var.ansible_inventory_path}" ] && [ -f "${var.ansible_playbook_path}" ]; then
        echo "================================================================="
        echo " [GCP Disk Resizer] Running Ansible partition & filesystem expansion..."
        echo " Inventory: ${var.ansible_inventory_path}"
        echo " Playbook:  ${var.ansible_playbook_path}"
        echo "================================================================="
        ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${var.ansible_inventory_path}" "${var.ansible_playbook_path}"
      else
        echo "Skipping Ansible expansion: Inventory or playbook file not found."
      fi
    EOT
  }

  depends_on = [terraform_data.resize_disk]
}
