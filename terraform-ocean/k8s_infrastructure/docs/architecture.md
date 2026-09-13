# Kubernetes Multi-Cloud Infrastructure Architecture

This project provisions a hybrid/multi-cloud Kubernetes infrastructure combining **Google Cloud Platform (GCP)**, **Amazon Web Services (AWS)**, and **DigitalOcean** for deployment with Kubespray.

## Multi-Cloud Topology Options

The architecture supports dynamic distribution across providers:
- **GCP**: Control Plane nodes (Compute Engine VMs) with stacked HA etcd quorum.
- **AWS**: Worker and/or Control Plane nodes (EC2 instances with Elastic IPs and multi-AZ distribution).
- **DigitalOcean**: Worker and/or Control Plane nodes (Droplets with static Reserved IPs and stockout fallback).

### Example Topologies:
1. **GCP Masters + AWS Workers**: 3 GCP control plane nodes + 4 AWS worker nodes.
2. **Tri-Cloud HA Quorum**: 1 GCP master + 1 AWS master + 1 DigitalOcean master (survives any full cloud outage).
3. **Pure DigitalOcean**: All masters and workers on DigitalOcean.
4. **Hybrid Workers**: Split worker nodes across AWS and DigitalOcean for multi-provider burst capacity.

## Structure

```text
k8s_infrastructure/
|-- README.md
|-- docs/
|   |-- architecture.md
|   |-- runbook.md
|   |-- disaster-recovery.md
|   `-- gcp-vm-error-handling.md
|
|-- modules/
|   |-- gcp-kubespray-cluster/           # GCP Control Plane & Worker module
|   |   |-- main.tf
|   |   |-- variables.tf
|   |   |-- outputs.tf
|   |   |-- versions.tf
|   |   `-- README.md
|   |
|   |-- aws-kubespray-workers/           # AWS Worker & Control Plane module
|   |   |-- main.tf
|   |   |-- variables.tf
|   |   |-- outputs.tf
|   |   |-- versions.tf
|   |   |-- templates/
|   |   |   `-- user_data.tftpl
|   |   `-- README.md
|   |
|   `-- digitalocean-kubespray-cluster/  # DigitalOcean Cluster module
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
|               |   |-- ansible_inventory.tftpl
|               |   `-- wireguard_inventory.tftpl
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
  | gcp_control_plane_count / aws_control_plane_count / digitalocean_control_plane_count
  | gcp_worker_count / aws_worker_count / digitalocean_worker_count
  | SSH keys / cloud regions / fallback configurations
  v
live/dev/asia-southeast1/kubespray-k8s
  |
  +---> calls modules/gcp-kubespray-cluster
  |       -> creates GCP control plane VMs + static external IPs + firewall rules
  |
  +---> calls modules/aws-kubespray-workers
  |       -> creates AWS EC2 worker instances + Elastic IPs + security group
  |       -> distributes across AWS availability zones
  |
  +---> calls modules/digitalocean-kubespray-cluster
  |       -> creates DO Droplets + static Reserved IPs + cloud firewall
  |       -> handles region discovery & stockout size fallbacks
  |
  v
kubespray_inventory.tf
  |
  | renders templates/kubespray_inventory.tftpl & wireguard_inventory.tftpl
  | writes combined GCP + AWS + DigitalOcean nodes
  v
Inventories generated:
  - ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini (Kubespray)
  - wiregurad/inventory/hosts.ini (WireGuard Full Mesh)
  - ansible_kubespray_k8s/inventory.ini (Ansible utility)
  |
  v
Ansible / Kubespray execution
```

## Inventory Mapping

Terraform generates the inventory combining all clouds over the WireGuard full-mesh overlay:

```ini
[kube_control_plane]
master01 ansible_host=34.x.x.x  ip=10.0.0.1 access_ip=10.0.0.1 etcd_member_name=master01
master02 ansible_host=34.x.x.y  ip=10.0.0.2 access_ip=10.0.0.2 etcd_member_name=master02
master03 ansible_host=18.x.x.z  ip=10.0.0.3 access_ip=10.0.0.3 etcd_member_name=master03

[kube_node]
worker01 ansible_host=54.x.x.a  ip=10.0.0.4 access_ip=10.0.0.4
worker02 ansible_host=54.x.x.b  ip=10.0.0.5 access_ip=10.0.0.5
worker03 ansible_host=54.x.x.c  ip=10.0.0.6 access_ip=10.0.0.6
worker04 ansible_host=54.x.x.d  ip=10.0.0.7 access_ip=10.0.0.7
worker05 ansible_host=159.x.x.e ip=10.0.0.8 access_ip=10.0.0.8  # DigitalOcean Droplet
```

- `ansible_host`: Public IP of the VM / Droplet (used solely by your workstation/deployer to establish SSH sessions).
- `ip`: WireGuard mesh IP (`10.0.0.x`), used by internal cluster daemons (kubelet, etcd, kube-proxy) to bind to and report.
- `access_ip`: WireGuard mesh IP (`10.0.0.x`), used by other cluster nodes to communicate over the encrypted `wg0` tunnel.
- Calico CNI auto-detects `interface=wg.*` to route inter-node Pod VXLAN packets across the WireGuard tunnel with MTU 1370.
