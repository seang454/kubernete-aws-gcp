# 💽 GCP In-Place Boot Disk Resizer Module

This module enables **online, zero-downtime, in-place disk resizing** for Google Cloud VMs managed by Terraform.

---

## ❓ Why This Module Exists

In Terraform's Google Provider (`google_compute_instance`), boot disk parameters configured via `boot_disk.initialize_params.size` are marked as **`Forces new resource`**.

If you attempt to increase the boot disk size directly on `google_compute_instance`, Terraform's default behavior is to **destroy and recreate the VM**, leading to catastrophic cluster state loss. To prevent this, VM instances typically specify:

```hcl
lifecycle {
  ignore_changes = [
    boot_disk[0].initialize_params[0].size,
    boot_disk[0].initialize_params[0].image,
  ]
}
```

However, this means simply changing `control_plane_boot_disk_size_gb` in `terraform.tfvars` does **not** actually expand the existing VM's disk in GCP.

---

## 🚀 How This Module Solves It

Google Cloud natively supports **online disk expansion** (`compute.disks.resize`) while instances are running without rebooting or recreating them.

This module automates that exact API call via `gcloud compute disks resize`:
1. **Change Detection:** Uses `terraform_data` with `triggers_replace = [target_size_gb, disk_name, zone]`.
2. **Safe Pre-Check:** Checks the current disk size via `gcloud compute disks describe`. If the disk is already at or above the target size, it skips safely.
3. **In-Place Resize:** If the current disk size is less than the target size, it executes `gcloud compute disks resize` online.
4. **Verification:** Prints an updated status table showing the new size and `READY` status.
5. **Optional Ansible Integration:** Can automatically trigger `ansible-playbook expand-disk.yml` to grow the OS partition (`growpart`) and filesystem (`resize2fs`) inside Ubuntu.

---

## 📋 Example Usage

```hcl
module "gcp_disk_resizer" {
  source = "../../../../modules/gcp-disk-resizer"

  enabled    = var.enable_gcp
  project_id = var.project_id

  disks = merge(
    {
      for node in module.gcp_kubespray_cluster.control_plane_nodes :
      node.name => {
        disk_name      = node.instance_name
        zone           = node.zone
        target_size_gb = var.control_plane_boot_disk_size_gb
      }
    },
    {
      for node in module.gcp_kubespray_cluster.worker_nodes :
      node.name => {
        disk_name      = node.instance_name
        zone           = node.zone
        target_size_gb = var.worker_boot_disk_size_gb
      }
    }
  )

  auto_expand_filesystem = false  # Set to true to automatically run Ansible expand-disk.yml
  ansible_inventory_path = abspath("${path.module}/${var.increase_disk_inventory_path}")
  ansible_playbook_path  = abspath("${path.module}/../../../../../increase-disk-alignment/expand-disk.yml")

  depends_on = [
    module.gcp_kubespray_cluster,
    local_file.increase_disk_inventory
  ]
}
```
