# Multi-Cloud Terraform Error Handling & Resilience Guide
## GCP, AWS, and DigitalOcean Architecture Parity

This guide explains how errors, stockouts, capacity limits, power cycling, and recovery are handled across all three cloud providers in `k8s_infrastructure`.

---

## 1. Resilience & Parity Matrix

| Feature / Problem | GCP (`gcp-kubespray-cluster`) | AWS (`aws-kubespray-workers`) | DigitalOcean (`digitalocean-kubespray-cluster`) |
| :--- | :--- | :--- | :--- |
| **Zone/Region Health Discovery** | `data.google_compute_zones` (`status = "UP"`) | `data.aws_availability_zones` (`state = "available"`) | `data.digitalocean_regions` (`available = true`) |
| **Capacity Stockout Fallback** | `blocked_zones`, `blocked_machine_types` ➔ `fallback_machine_types` | `blocked_zones`, `blocked_machine_types` ➔ `fallback_machine_types` | `blocked_regions`, `blocked_sizes` ➔ `fallback_sizes` |
| **Static IP Persistence** | `google_compute_address` (retained across rebuilds) | `aws_eip` (Elastic IP retained across rebuilds) | `digitalocean_reserved_ip` (Reserved IP retained across rebuilds) |
| **Secondary Data Disks** | `google_compute_disk` + attachment | `aws_ebs_volume` + attachment | `digitalocean_volume` + attachment |
| **In-Place Power Control** | `desired_status = "TERMINATED"` | `aws_ec2_instance_state` (`stopped`/`running`) | `terraform_data.droplet_power` API Action (`power_off`/`power_on`) |
| **Selective VM Deletion** | `exclude_nodes = ["k8s-..."]` | `exclude_nodes = ["k8s-..."]` | `exclude_nodes = ["k8s-..."]` |
| **Selective VM Power Off** | `stop_nodes = ["k8s-..."]` | `stop_nodes = ["k8s-..."]` | `stop_nodes = ["k8s-..."]` |
| **Inventory Self-Healing** | `exclude_stopped_nodes_from_inventory` | `exclude_stopped_nodes_from_inventory` | `exclude_stopped_nodes_from_inventory` |
| **Cross-Cloud Firewalling** | Automatic GCP firewall rules for AWS + DO CIDRs/IPs | AWS Security Group allows GCP + DO IPs | DO Cloud Firewall allows GCP + AWS IPs |
| **Cross-Cloud Mesh** | WireGuard full-mesh overlay (UDP 51820) | WireGuard full-mesh overlay (UDP 51820) | WireGuard full-mesh overlay (UDP 51820) |

---

## 2. Common Errors and Resolutions

### Error A: Machine Size or Type Stockout
* **GCP Symptoms:** `ZONE_RESOURCE_POOL_EXHAUSTED` or `The zone ... does not have enough resources`.
  - **Fix:** In `terraform.tfvars`:
    ```hcl
    blocked_machine_types = ["e2-medium"]
    ```
    Terraform instantly calculates the next candidate from `fallback_machine_types` (e.g. `e2-standard-2`).

* **AWS Symptoms:** `InsufficientInstanceCapacity` or `VcpuLimitExceeded`.
  - **Fix:** In `terraform.tfvars`:
    ```hcl
    aws_blocked_machine_types = ["t3.medium"]
    ```
    Terraform automatically rebinds instances to `t3a.medium` or `m5.large`.

* **DigitalOcean Symptoms:** `Droplet size 's-2vcpu-4gb' is currently unavailable in region 'sgp1'`.
  - **Fix:** In `terraform.tfvars`:
    ```hcl
    digitalocean_blocked_sizes = ["s-2vcpu-4gb"]
    ```
    Terraform automatically selects the next size in `digitalocean_fallback_sizes` (e.g. `s-4vcpu-8gb` or `c-2`).

---

### Error B: Region / Datacenter Maintenance
* **GCP:** Add zone to `blocked_zones = ["asia-east1-a"]`. Nodes shift to `asia-east1-b` or `asia-east1-c`.
* **AWS:** Add AZ to `aws_blocked_availability_zones = ["ap-southeast-1a"]`. Subnets and instances shift to `ap-southeast-1b`.
* **DigitalOcean:** Add region to `digitalocean_blocked_regions = ["sgp1"]`. Droplets rebalance to remaining regions in `digitalocean_regions` or candidate UP list.

---

### Error C: Temporary Cost Savings vs. Permanent Teardown
1. **To Power Down Nodes (Keep IPs, Disks, and Configurations intact):**
   ```bash
   ./scripts/stop-machines.sh k8s-worker03 k8s-worker04
   # Or stop the entire cluster:
   ./scripts/stop-machines.sh
   ```
2. **To Power Back On:**
   ```bash
   ./scripts/start-machines.sh
   ```
3. **To Permanently Delete a Compromised or Unneeded Node:**
   ```bash
   ./scripts/delete-machines.sh k8s-worker04
   ```
   Removing the node from `exclude_nodes` will cleanly recreate it from scratch.

---

### Error D: Cross-Cloud Network Isolation
* All nodes across GCP, AWS, and DigitalOcean participate in an encrypted WireGuard mesh network:
  - WireGuard interface: `wg0`
  - Subnet: `10.0.0.0/24`
  - MTU: `1370` (handles cross-cloud UDP encapsulation overhead)
* Kubespray and Calico are configured to bind exclusively to the WireGuard mesh IPs (`10.0.0.x`), ensuring uniform flat networking regardless of individual cloud VPC CIDR layouts.

---

### Error E: Disabling Unused Cloud Providers (`enable_gcp`, `enable_aws`, `enable_digitalocean`)
* **Problem / Goal:** When managing a multi-cloud cluster, you may not want to touch, query, or provide API credentials for cloud providers you are not actively using (for instance, skipping DigitalOcean when running purely GCP + AWS, or skipping AWS when running purely GCP + DO).
* **Fix:** In `terraform.tfvars`:
  ```hcl
  enable_gcp          = true
  enable_aws          = true
  enable_digitalocean = false
  ```
* **How It Works:**
  - When `enable_<cloud> = false`, the root module sets the effective control plane and worker counts for that cloud to `0` and passes `enabled = false` to the module.
  - All data sources (e.g. `data.digitalocean_regions.available`, `data.aws_vpc`, `data.aws_availability_zones`, `data.google_compute_zones`) are guarded and bypassed. No remote API queries are executed, avoiding 401 Unauthorized or credential validation errors.
  - Submodule node planning lists evaluate to empty lists (`[]`), and resource blocks using `for_each` evaluate to empty maps (`{}`).
  - Preflight checks for disabled clouds are bypassed.
  - Cross-cloud firewall rules targeting disabled clouds (e.g. `allow_digitalocean_nodes` or `allow_aws_workers`) evaluate count to `0` and are not created.

