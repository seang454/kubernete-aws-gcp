# Kubernetes Multi-Cloud Infrastructure (AWS + GCP + DigitalOcean)

This Terraform project provisions a flexible hybrid/multi-cloud Kubernetes infrastructure for Kubespray:
- **Control Plane Nodes on GCP** (Compute Engine VMs with HA stacked etcd)
- **Worker Nodes on AWS** (EC2 instances with Elastic IPs and multi-AZ distribution)
- **Control Plane / Worker Nodes on DigitalOcean** (Droplets with static Reserved IPs and stockout protection)

Terraform automatically configures all cloud providers, provisions cross-cloud firewall rules, and generates ready-to-use Kubespray, WireGuard, and Ansible inventories containing the real VM IP addresses.

## Architecture Flow

```text
terraform.tfvars
  -> Control Plane: Any split across GCP, AWS, and DigitalOcean (e.g. 2 GCP + 1 AWS + 0 DO, or 1/1/1 HA Quorum)
  -> Worker Nodes:  Any split across GCP, AWS, and DigitalOcean (e.g. 4 AWS + 2 DO)
  -> SSH user/key, regions, and network CIDRs

Terraform
  -> creates GCP control plane VMs + static external IPs
  -> creates AWS worker EC2 instances + Elastic IPs + security group
  -> creates DigitalOcean Droplets + static Reserved IPs + cloud firewall
  -> writes Kubespray inventory.ini (with WireGuard 10.0.0.x access_ip configuration)
  -> writes WireGuard hosts.ini (for full-mesh encryption)
  -> writes Ansible inventory.ini

Kubespray
  -> reads inventory.ini
  -> installs Kubernetes HA cluster across GCP, AWS, and DigitalOcean with Ansible
```

## Directory Structure

```text
k8s_infrastructure/
|-- live/
|   `-- dev/
|       `-- asia-southeast1/
|           `-- kubespray-k8s/           # Main root module (tri-cloud orchestration)
|-- modules/
|   |-- gcp-kubespray-cluster/           # GCP control plane & worker module
|   |-- aws-kubespray-workers/           # AWS worker & control plane module
|   `-- digitalocean-kubespray-cluster/  # DigitalOcean control plane & worker module
|-- scripts/                             # Operational automation scripts
`-- docs/                                # Architecture, runbooks & disaster recovery
```

## Generated Inventories

- **Kubespray Inventory**: `terraform/ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini`
- **Ansible Utility Inventory**: `terraform/ansible_kubespray_k8s/inventory.ini`

## How to Run

### 1. Prerequisites & Credentials

- **GCP**: Authenticate with Application Default Credentials:
  ```bash
  gcloud auth application-default login
  ```
- **AWS**: Configure AWS credentials via AWS CLI or environment variables:
  ```bash
  export AWS_ACCESS_KEY_ID="your-access-key"
  export AWS_SECRET_ACCESS_KEY="your-secret-key"
  export AWS_REGION="ap-southeast-1"
  ```
  (Alternatively, configure `~/.aws/credentials` or set `aws_profile` in `terraform.tfvars`).
- **DigitalOcean**: Export token in shell or set `do_token` in `terraform.tfvars`:
  ```bash
  export DIGITALOCEAN_TOKEN="dop_v1_your_token_here"
  ```

### 2. Deploy Infrastructure

```bash
cd terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s
terraform init
terraform apply
```

### 3. Deploy Kubernetes with Kubespray

```bash
cd terraform/ansible_kubespray_k8s/kubespray
ansible-playbook -i inventory/sample/inventory.ini cluster.yml
```

## Selective Node Management: Delete vs Stop

You can exclude nodes in two distinct ways in `terraform.tfvars`:

| Operation | Variable | Behavior | Recovery (Remove from list) |
| :--- | :--- | :--- | :--- |
| **Delete / Destroy** | `exclude_nodes = ["k8s-worker04"]` | Permanently destroys the VM, disks, and Elastic/static IP. | Terraform **creates/recreates** the node with all resources. |
| **Stop / Power Off** | `stop_nodes = ["k8s-worker04"]` | Powers down the VM without deleting anything (disks, IPs preserved). | Terraform **powers back on (starts)** the node into `RUNNING`. |

Stopped nodes are automatically excluded from `inventory.ini` so Kubespray and Ansible playbooks do not time out on powered-off instances.

## Operational Scripts

From `terraform/k8s_infrastructure/`:

- **Stop machines** (power off VMs without deleting):
  ```bash
  ./scripts/stop-machines.sh                          # Stop ALL machines
  ./scripts/stop-machines.sh k8s-worker03 k8s-worker04 # Stop SPECIFIC machines
  ./scripts/stop-machines.sh --list                   # List running and stopped nodes
  ```
- **Start machines** (power on VMs):
  ```bash
  ./scripts/start-machines.sh                          # Start ALL machines
  ./scripts/start-machines.sh k8s-worker03             # Start SPECIFIC stopped machines
  ./scripts/start-machines.sh --list                   # List stopped nodes
  ```
- **Delete specific nodes** (permanently destroy):
  ```bash
  ./scripts/delete-machines.sh --list                  # List all instance names
  ./scripts/delete-machines.sh k8s-worker04            # Delete specific node
  ```
- **Validate all configurations**:
  ```bash
  ./scripts/validate-all.sh
  ```
