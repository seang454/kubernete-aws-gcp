# Dev Kubespray Multi-Cloud Infrastructure (GCP + AWS + DigitalOcean)

This Terraform root creates VMs across GCP, AWS, and DigitalOcean for a multi-cloud Kubespray Kubernetes cluster and writes the real node IPs into the Kubespray and WireGuard inventories.

Terraform creates:

- Control plane VMs across GCP, AWS, and DigitalOcean (e.g. `master01`, `master02`, `master03`).
- Worker VMs across GCP, AWS, and DigitalOcean (e.g. `worker01`, `worker02`, `worker03`, `worker04`, `worker05`).
- Static external IPs (GCP static addresses, AWS Elastic IPs, DigitalOcean Reserved IPs).
- A local SSH key pair when `ansible_ssh_private_key_file` and `ssh_public_key_path` do not already exist.
- Internal/WireGuard IPs used by Kubespray as `ip=10.0.0.x`.
- Cross-cloud firewall and security group rules for SSH, WireGuard (UDP 51820), and Kubernetes API.
- The generated Kubespray inventory file and WireGuard mesh configuration.

Terraform does not run Kubespray. After `terraform apply`, deploy WireGuard and run Kubespray with Ansible.

## Configure Node Counts

Use `terraform.tfvars`:

```hcl
gcp_control_plane_count          = 2
aws_control_plane_count          = 1
digitalocean_control_plane_count = 0

gcp_worker_count                 = 0
aws_worker_count                 = 4
digitalocean_worker_count        = 0
```

For stacked etcd, `1` or `3` control plane nodes is usually recommended for HA quorum.

## Generated Inventory

Terraform writes:

```text
terraform/ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini
```

The inventory format lives in:

```text
templates/kubespray_inventory.tftpl
```

Terraform renders it with `templatefile()` and then writes the result with the `local_file` resource.

Example generated inventory:

```ini
[kube_control_plane]
master01 ansible_host=<master01-public-ip> ip=<master01-private-ip> etcd_member_name=master01
master02 ansible_host=<master02-public-ip> ip=<master02-private-ip> etcd_member_name=master02

[etcd:children]
kube_control_plane

[kube_node]
worker01 ansible_host=<worker01-public-ip> ip=<worker01-private-ip>

[k8s_cluster:children]
kube_control_plane
kube_node
```

`ansible_host` is the external IP Ansible uses for SSH.

`ip` is the internal GCP IP Kubernetes nodes use to talk to each other.

## Run Terraform

First create Application Default Credentials for the user running Terraform:

```bash
gcloud auth application-default login
```

Keep the portable default in `terraform.tfvars`:

```hcl
gcp_adc_file = ""
```

An empty value tells the Google provider to automatically discover that user's
ADC credentials. To explicitly select the standard Linux/WSL file without
hardcoding a username, use:

```hcl
gcp_adc_file = "~/.config/gcloud/application_default_credentials.json"
```

Terraform expands `~` to the current user's home directory.

Terraform also checks these SSH key paths:

```hcl
ssh_public_key_path           = "~/.ssh/id_rsa.pub"
ansible_ssh_private_key_file  = "~/.ssh/id_rsa"
```

If both files already exist, Terraform reuses them. If one or both are missing,
Terraform generates a new RSA key pair, writes it under `~/.ssh`, and injects the
public key into each GCP VM's `ssh-keys` metadata for `ssh_user`.

```bash
cd terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s
terraform init
terraform plan
terraform apply
terraform output kubespray_inventory_path
terraform output control_plane_nodes
terraform output worker_nodes
```

## Run Kubespray

After Terraform finishes:

```bash
cd terraform/ansible_kubespray_k8s/kubespray
ansible-playbook -i inventory/sample/inventory.ini cluster.yml
```

---

## 🚀 Supported Run Modes & Cluster Operations Guide

This cluster architecture supports multiple operational run modes to match your purpose:

### 1. Full Cluster Deployment (All Nodes Active)
Deploys or resumes all control planes and worker nodes across all enabled clouds:
```bash
terraform apply -var="desired_status=RUNNING"
```

---

### 2. Cost-Saving / Sleep Mode ($0 Compute Cost)
Powers off all VMs across GCP and AWS without deleting them. All root disks, secondary disks, static public IPs, and cluster configurations are preserved:
```bash
terraform apply -var="desired_status=TERMINATED"
```
> **Tip:** Run this whenever you finish testing for the day to drop compute billing to $0/hr while keeping everything intact.

---

### 3. Selective Node Stopping (`stop_nodes`)
Keep specific nodes running while pausing others without destroying them:

In `terraform.tfvars`:
```hcl
stop_nodes = ["k8s-worker03", "k8s-worker04"]
```
Then run:
```bash
terraform apply -var="desired_status=RUNNING"
```
- `master01`, `master02`, `master03`, `worker01`, `worker02` will remain active.
- `worker03` and `worker04` are kept in a stopped state ($0 compute).
- Remove them from `stop_nodes = []` and apply to power them back on anytime.

---

### 4. Resizing RAM & CPU In-Place (Zero VM Replacement)
All cloud providers in this configuration support in-place machine type updates without destroying the VMs:

In `terraform.tfvars`:
```hcl
# GCP Control Plane (e2-medium 4GB -> e2-standard-2 8GB):
control_plane_machine_types = ["e2-standard-2"]

# AWS Workers (t3.small 2GB -> t3.medium 4GB):
aws_worker_machine_types = ["t3.medium"]
```
Then run:
```bash
terraform apply -var="desired_status=RUNNING"
```
*(Terraform gracefully stops the VM, modifies CPU/RAM via the cloud provider API, and restarts it in-place).*

---

### 5. Resizing Boot Disks Online (Zero Downtime)
Expand storage capacity (e.g. from 50 GB to 60 GB or 100 GB):

1. Update target sizes in `terraform.tfvars`:
   ```hcl
   control_plane_boot_disk_size_gb     = 60
   aws_worker_root_disk_size_gb        = 60
   aws_control_plane_boot_disk_size_gb = 60
   ```
2. Apply with Terraform:
   ```bash
   terraform apply -var="desired_status=RUNNING"
   ```
   - **GCP:** Handled automatically by the `gcp-disk-resizer` module using `gcloud compute disks resize` online.
   - **AWS:** Expanded online via AWS EBS volume resize.
3. Expand Linux partitions & filesystem online (no reboot needed):
   ```bash
   cd ~/kubernete-aws-gcp/terraform/increase-disk-alignment
   ansible-playbook -i inventory.ini expand-disk.yml
   ```
   *(Or set `auto_expand_disk_filesystem = true` in `terraform.tfvars` for Terraform to trigger this automatically).*

---

### 6. Cloud Provider Toggles
You can selectively enable or disable entire cloud providers based on your purpose:

In `terraform.tfvars`:
```hcl
enable_gcp          = true   # Set false to bypass GCP
enable_aws          = true   # Set false to bypass AWS completely ($0 cost)
enable_digitalocean = false  # Set true when ready for DO
```

---

### 7. Explicit Image / AMI Locking
Each cloud has its OS image explicitly locked in `terraform.tfvars` to prevent accidental drift:

```hcl
# GCP:
image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"

# AWS (x86_64 for t3 instances):
aws_worker_ami_id = "ami-0ba4172b23e57d5a8"

# AWS (ARM64 for t4g Graviton instances):
# aws_worker_ami_id = "ami-0f78fc0711eeb6f28"

# DigitalOcean:
digitalocean_image = "ubuntu-24-04-x64"
```

---

### 8. Anti-Destruction Protection (`prevent_destroy`)
To prevent accidental VM deletion (from typos, incompatible machine types, or accidental commands):
- Every VM resource across GCP, AWS, and DigitalOcean has **`prevent_destroy = true`**.
- Any command or configuration change that would accidentally replace or destroy an existing VM is **immediately blocked by Terraform with an error**.

#### How to Intentionally Destroy Specific Nodes (`exclude_nodes`):
When you want to permanently delete/destroy a specific node (e.g. `k8s-worker04`) while keeping the rest of the cluster intact:

```bash
# 1. Temporarily unlock destroy protection:
./toggle_destroy_protection.sh disable

# 2. Add the node name to exclude_nodes in terraform.tfvars:
# exclude_nodes = ["k8s-worker04"]

# 3. Apply the deletion (Terraform will only destroy the targeted node):
terraform apply -var="desired_status=RUNNING"

# 4. Immediately re-lock destroy protection to safeguard remaining nodes:
./toggle_destroy_protection.sh enable
```

> [!TIP]
> **Prefer `stop_nodes` if you only want to save money!**
> If you don't need to permanently delete the VM, disk, and IP, use `stop_nodes = ["k8s-worker04"]` instead. It stops the VM ($0 compute billing) while preserving all data and IP allocations, and **does not require** unlocking `prevent_destroy`.

#### How to Intentionally Destroy All Machines:
When you genuinely want to tear down the entire cluster:

```bash
# 1. Unlock destroy protection:
./toggle_destroy_protection.sh disable

# 2. Run terraform destroy:
terraform destroy

# 3. Re-lock protection:
./toggle_destroy_protection.sh enable
```

To check current protection status at any time:
```bash
./toggle_destroy_protection.sh status
```

---

## Important Variables Summary

```hcl
control_plane_count = 3
worker_count        = 4

ssh_user            = "seang"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Empty means reuse ssh_user.
ansible_user                 = ""
ansible_ssh_private_key_file = "~/.ssh/id_rsa"

kubespray_inventory_path = "../../../../../ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini"
```
