# 💽 Automated Online Disk Alignment & Expansion (`increase-disk-alignment`)

This Ansible automation expands partition tables and filesystems online across all Kubernetes nodes in your hybrid cluster (**AWS**, **GCP**, and **DigitalOcean**) without rebooting the VMs or causing downtime.

---

## 🚀 How to Run

```bash
cd ~/kubernete-aws-gcp/terraform/increase-disk-alignment
ansible-playbook -i inventory.ini expand-disk.yml
```

---

## 🛠️ What This Playbook Does

1. **Snapshots Disk State Before Expansion:** Runs `df -h /` on all nodes to record current sizes.
2. **Installs Required Utilities:** Ensures `cloud-guest-utils` (`growpart`) and `e2fsprogs` (`resize2fs`) are installed.
3. **Auto-Detects Block Devices:**
   - **AWS (NVMe Nitro):** Identifies `/dev/nvme0n1` and partition `1`.
   - **GCP / DigitalOcean (SCSI / VirtIO):** Identifies `/dev/sda` or `/dev/vda` and partition `1`.
4. **Grows Partition Table:** Runs `growpart` to expand the partition to fill the full 50 GB block storage.
5. **Expands Filesystem Online:** Runs `resize2fs` (for ext4) or `xfs_growfs` (for xfs) while the operating system is running.
6. **Notifies Kubelet:** Safely restarts `kubelet` so Kubernetes instantly detects the new disk capacity without waiting.
7. **Prints Summary:** Displays a clean Before vs. After comparison for each node.

---

## 🔄 Terraform Auto-Generation

Terraform automatically updates `inventory.ini` in this directory whenever `terraform apply` runs in:
- `terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s`
- `terraform-ocean/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s`
