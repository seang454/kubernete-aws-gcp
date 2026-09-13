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

## Stopping and Starting Machines

To stop (power off) the created VMs without destroying them or losing configuration:

Via CLI:
```bash
terraform apply -var="desired_status=TERMINATED"
```

Or run the helper script:
```bash
../../../scripts/stop-machines.sh
```

To start (power on) the machines back up:

Via CLI:
```bash
terraform apply -var="desired_status=RUNNING"
```

Or run the helper script:
```bash
../../../scripts/start-machines.sh
```

Or set `desired_status = "TERMINATED"` (or `"RUNNING"`) in `terraform.tfvars` and run `terraform apply`.

## Important Variables

```hcl
control_plane_count = 3
worker_count        = 3

ssh_user            = "seang"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Empty means reuse ssh_user.
ansible_user                 = ""
ansible_ssh_private_key_file = "~/.ssh/id_rsa"

kubespray_inventory_path = "../../../../../ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini"
```

## What Was Removed

This Kubernetes infra does not use:

- Cloudflare DNS records.
- SonarQube/Jenkins/Nexus/DefectDojo/Trivy/Vault service inventory.
- Terraform-generated Ansible service `group_vars`.

Those belong to `terraform/infrastructure`, not `terraform/k8s_infrastructure`.
