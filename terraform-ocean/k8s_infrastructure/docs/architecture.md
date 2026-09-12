# Kubernetes Multi-Cloud Infrastructure Architecture

This project provisions a hybrid-cloud Kubernetes infrastructure combining **Google Cloud Platform (GCP)** and **Amazon Web Services (AWS)** for deployment with Kubespray.

## Hybrid Topology

- **GCP**: 3 Control Plane nodes (`master01`, `master02`, `master03`) with stacked HA etcd quorum.
- **AWS**: 4 Worker nodes (`worker01`, `worker02`, `worker03`, `worker04`) distributed across multiple availability zones with Elastic IPs.

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
|   |-- gcp-kubespray-cluster/       # GCP Control Plane (Compute Engine)
|   |   |-- main.tf
|   |   |-- variables.tf
|   |   |-- outputs.tf
|   |   |-- versions.tf
|   |   `-- README.md
|   |
|   `-- aws-kubespray-workers/       # AWS Worker Nodes (EC2 Instances)
|       |-- main.tf
|       |-- variables.tf
|       |-- outputs.tf
|       |-- versions.tf
|       |-- templates/
|       |   `-- user_data.tftpl
|       `-- README.md
|
|-- live/
|   `-- dev/
|       `-- asia-southeast1/
|           `-- kubespray-k8s/
|               |-- backend.tf
|               |-- providers.tf
|               |-- kubespray_cluster.tf
|               |-- kubespray_inventory.tf
|               |-- templates/
|               |   |-- kubespray_inventory.tftpl
|               |   `-- ansible_inventory.tftpl
|               |-- variables.tf
|               |-- outputs.tf
|               |-- terraform.tfvars
|               |-- terraform.tfvars.example
|               `-- README.md
|
`-- scripts/
    |-- validate-all.sh
    |-- check-format.sh
    |-- stop-machines.sh
    |-- start-machines.sh
    |-- delete-machines.sh
    `-- apply-dev-and-run-ansible.sh
```

## Flow

```text
terraform.tfvars
  |
  | control_plane_count = 3 (GCP)
  | aws_worker_count = 4 (AWS)
  | gcp_worker_count = 0
  | SSH keys / cloud regions
  v
live/dev/asia-southeast1/kubespray-k8s
  |
  +---> calls modules/gcp-kubespray-cluster
  |       -> creates 3 GCP control plane VMs + static external IPs + firewall rules
  |
  +---> calls modules/aws-kubespray-workers
  |       -> creates 4 AWS EC2 worker instances + Elastic IPs + security group
  |       -> distributes across AWS availability zones
  |
  v
kubespray_inventory.tf
  |
  | renders templates/kubespray_inventory.tftpl
  | writes combined GCP + AWS nodes
  v
terraform/ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini
  |
  | used by
  v
Kubespray Ansible cluster.yml
```

## Inventory Mapping

Terraform generates the inventory combining both clouds over the WireGuard full-mesh overlay:

```ini
[kube_control_plane]
master01 ansible_host=34.x.x.x ip=10.0.0.1 access_ip=10.0.0.1 etcd_member_name=master01
master02 ansible_host=34.x.x.y ip=10.0.0.2 access_ip=10.0.0.2 etcd_member_name=master02
master03 ansible_host=34.x.x.z ip=10.0.0.3 access_ip=10.0.0.3 etcd_member_name=master03

[kube_node]
worker01 ansible_host=54.x.x.a ip=10.0.0.4 access_ip=10.0.0.4
worker02 ansible_host=54.x.x.b ip=10.0.0.5 access_ip=10.0.0.5
worker03 ansible_host=54.x.x.c ip=10.0.0.6 access_ip=10.0.0.6
worker04 ansible_host=54.x.x.d ip=10.0.0.7 access_ip=10.0.0.7
```

- `ansible_host`: Public IP of the VM (used solely by your workstation/deployer to establish SSH sessions).
- `ip`: WireGuard mesh IP (`10.0.0.x`), used by internal cluster daemons (kubelet, etcd, kube-proxy) to bind to and report.
- `access_ip`: WireGuard mesh IP (`10.0.0.x`), used by other cluster nodes to communicate over the encrypted `wg0` tunnel.
- Calico CNI auto-detects `interface=wg.*` to route inter-node Pod VXLAN packets across the WireGuard tunnel with MTU 1370.
