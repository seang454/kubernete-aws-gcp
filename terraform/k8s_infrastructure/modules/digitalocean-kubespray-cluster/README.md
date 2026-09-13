# 🌊 DigitalOcean Kubespray Nodes Module

This Terraform module deploys Kubernetes worker and/or control plane nodes on **DigitalOcean**, designed for hybrid multi-cloud clusters alongside **Google Cloud Platform (GCP)** and **Amazon Web Services (AWS)**.

It maintains **100% architectural parity** with the `gcp-kubespray-cluster` and `aws-kubespray-workers` modules.

---

## 🏗️ Core Architecture & Parity Matrix

| Feature / Concept | GCP Implementation | AWS Implementation | DigitalOcean Implementation |
| :--- | :--- | :--- | :--- |
| **Compute Primitive** | `google_compute_instance` | `aws_instance` | `digitalocean_droplet` |
| **Region / Zone Discovery** | `data.google_compute_zones` (UP) | `data.aws_availability_zones` (available) | `data.digitalocean_regions` (available) |
| **Stockout Fallback** | `blocked_machine_types` ➔ `e2-*` / `n1-*` | `blocked_machine_types` ➔ `t3.*` / `m5.*` | `blocked_sizes` ➔ `s-*` / `c-*` / `g-*` |
| **Static Public IP** | `google_compute_address` | `aws_eip` | `digitalocean_reserved_ip` |
| **Secondary Storage** | Persistent Disk attachment | Secondary EBS Volume attachment | DigitalOcean Block Storage Volume |
| **Cloud Firewall** | `google_compute_firewall` | `aws_security_group` | `digitalocean_firewall` |
| **Power State** | `desired_status = "TERMINATED"` | `aws_ec2_instance_state` | `terraform_data` DO API Action |
| **Selective Deletion** | `exclude_nodes` list | `exclude_nodes` list | `exclude_nodes` list |
| **Selective Power Off** | `stop_nodes` list | `stop_nodes` list | `stop_nodes` list |
| **Cross-Cloud Mesh** | WireGuard UDP 51820 | WireGuard UDP 51820 | WireGuard UDP 51820 |

---

## 🛠️ How Problems and Edge Cases are Handled

### 1. Droplet Size Stockouts & Datacenter Saturation
* **Problem:** DigitalOcean datacenters (especially `sgp1` and `nyc1`) can occasionally run out of specific droplet sizes (e.g. `s-2vcpu-4gb`).
* **Handling:**
  - `fallback_sizes`: Configurable priority list (e.g. `["s-4vcpu-8gb", "s-2vcpu-2gb", "c-2", "g-2vcpu-8gb"]`).
  - `blocked_sizes`: If an error occurs, simply add the size to `blocked_sizes = ["s-2vcpu-4gb"]`. Terraform automatically swaps to the next available size in the fallback list without recreating unaffected nodes.
  - `auto_discover_up_regions`: Queries the DigitalOcean API dynamically to ensure droplets are placed in operational regions.

### 2. Power State Management (Running vs. Stopped)
* **Problem:** Unlike AWS (`aws_ec2_instance_state`) and GCP (`desired_status`), the Terraform DigitalOcean provider lacks a native in-place power management resource.
* **Handling:**
  - This module uses a native `terraform_data.droplet_power` lifecycle trigger that calls the DigitalOcean REST API (`POST /v2/droplets/{id}/actions` with `power_off` or `power_on`).
  - When `desired_status = "TERMINATED"` or a node is in `stop_nodes`, the module automatically triggers a graceful power-off.
  - When switched back to `desired_status = "RUNNING"`, the droplets power back on without losing their configuration, state, or static IPs.

### 3. Stopped Droplets vs. Excluded Droplets (Billing Transparency)
* **Problem:** DigitalOcean bills for powered-off droplets because CPU, RAM, and SSD storage remain reserved for your account.
* **Handling:**
  - **Temporary Pause (`stop_nodes` or `desired_status = "TERMINATED"`):** Keeps the droplet, disks, and reserved IPs intact. Ideal for maintenance or overnight cost-saving on computing resources.
  - **Permanent Removal (`exclude_nodes`):** Destroys the droplet and associated resources completely, reducing billing to $0 for that node. Removing the node from `exclude_nodes` will cleanly recreate it.

### 4. Cross-Cloud Networking & VPC Isolation
* **Problem:** DigitalOcean VPCs are isolated to DigitalOcean and cannot natively peer with AWS VPCs or GCP VPCs without costly cloud interconnects.
* **Handling:**
  - **Full-Mesh WireGuard Overlay:** Each DigitalOcean droplet runs WireGuard on port `51820/udp`.
  - The module configures the `digitalocean_firewall` to allow UDP 51820 across all nodes.
  - All inter-cluster Kubernetes traffic flows through WireGuard point-to-point tunnel IPs (`10.0.0.X`), guaranteeing encrypted, flat Layer 3 connectivity across GCP, AWS, and DigitalOcean.

### 5. Static Reserved IP Preservation
* **Problem:** Standard DigitalOcean public IPs can change when a droplet is destroyed or rebuilt.
* **Handling:**
  - With `allocate_reserved_ips = true`, static Reserved IPs (Floating IPs) are attached to each droplet.
  - IPs remain static and persistent across droplet reboots, power cycles, and maintenance windows.

---

## 📋 Example Usage

```hcl
module "digitalocean_kubespray_cluster" {
  source = "../../../../modules/digitalocean-kubespray-cluster"

  cluster_name               = "kubespray"
  instance_name_prefix       = "k8s"
  control_plane_count        = 1 # 1 master node on DO
  control_plane_sizes        = ["s-2vcpu-4gb"]
  worker_count               = 2 # 2 worker nodes on DO
  worker_name_prefix         = "worker"
  index_offset               = 4 # Starts at worker05

  region                     = "sgp1"
  worker_sizes               = ["s-2vcpu-4gb"]
  fallback_sizes             = ["s-4vcpu-8gb", "c-2"]
  allocate_reserved_ips      = true

  ssh_user                   = "seang"
  ssh_public_key             = file("~/.ssh/id_rsa.pub")
  ssh_source_ranges          = ["0.0.0.0/0"]
  cluster_source_ranges      = ["10.0.0.0/8"]
  wireguard_source_ranges    = ["0.0.0.0/0"]

  desired_status             = "RUNNING"
  exclude_nodes              = []
  stop_nodes                 = []
}
```
