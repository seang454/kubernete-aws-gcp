# Kubernetes Infrastructure Architecture

This project is dedicated to Kubespray infrastructure.

It is separate from the service infrastructure used for SonarQube, Jenkins, Nexus, DefectDojo, Trivy, and Vault.

## Structure

```text
terraform/k8s_infrastructure/
|-- README.md
|-- docs/
|   |-- architecture.md
|   |-- runbook.md
|   |-- disaster-recovery.md
|
|-- modules/
|   |-- gcp-kubespray-cluster/
|       |-- main.tf
|       |-- variables.tf
|       |-- outputs.tf
|       |-- versions.tf
|       |-- README.md
|
|-- live/
|   |-- dev/
|       |-- asia-southeast1/
|           |-- kubespray-k8s/
|               |-- backend.tf
|               |-- providers.tf
|               |-- kubespray_cluster.tf
|               |-- kubespray_inventory.tf
|               |-- templates/
|               |   |-- kubespray_inventory.tftpl
|               |-- variables.tf
|               |-- outputs.tf
|               |-- terraform.tfvars.example
|               |-- README.md
|
|-- state/
|   |-- dev/
|       |-- asia-southeast1/
```

## Flow

```text
terraform.tfvars
  |
  | control_plane_count
  | worker_count
  | machine types
  | zones
  | SSH key/user
  v
live/dev/asia-southeast1/kubespray-k8s
  |
  | calls
  v
modules/gcp-kubespray-cluster
  |
  | creates
  v
GCP VMs + static external IPs + firewall rules
  |
  | outputs public/private IPs
  v
kubespray_inventory.tf
  |
  | renders templates/kubespray_inventory.tftpl
  | writes
  v
terraform/ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini
  |
  | used by
  v
Kubespray Ansible cluster.yml
```

## Inventory Mapping

Terraform writes each node with both public and private IPs:

```ini
master01 ansible_host=<external-ip> ip=<internal-ip> etcd_member_name=master01
worker01 ansible_host=<external-ip> ip=<internal-ip>
```

`ansible_host` is for SSH from the Ansible control machine.

`ip` is for Kubernetes node-to-node communication inside the VPC.

## What This Project Does Not Use

This Kubernetes infrastructure does not use Cloudflare DNS or service-specific Ansible group vars.

Cloudflare/service DNS belongs in:

```text
terraform/infrastructure
```
