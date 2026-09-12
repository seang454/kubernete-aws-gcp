# Kubernetes Multi-Cloud Infrastructure (AWS + GCP)

This Terraform project provisions a hybrid-cloud Kubernetes infrastructure for Kubespray:
- **3 Control Plane Nodes on GCP** (Compute Engine VMs with HA stacked etcd)
- **4 Worker Nodes on AWS** (EC2 instances with Elastic IPs and multi-AZ distribution)

Terraform automatically configures both cloud providers and generates ready-to-use Kubespray and Ansible inventories containing the real VM IP addresses.

## Architecture Flow

```text
terraform.tfvars
  -> Control Plane: 3 nodes on GCP (e2-medium)
  -> Worker Nodes:  4 nodes on AWS (t3.medium)
  -> SSH user/key, regions, and network CIDRs

Terraform
  -> creates 3 GCP control plane VMs + static external IPs
  -> creates 4 AWS worker EC2 instances + Elastic IPs + security group
  -> writes Kubespray inventory.ini (with cross-cloud access_ip configuration)
  -> writes Ansible inventory.ini

Kubespray
  -> reads inventory.ini
  -> installs Kubernetes HA cluster across GCP and AWS with Ansible
```

## Directory Structure

```text
terraform/k8s_infrastructure/
|-- live/
|   `-- dev/
|       `-- asia-southeast1/
|           `-- kubespray-k8s/           # Main root module
|-- modules/
|   |-- gcp-kubespray-cluster/           # GCP control plane module
|   `-- aws-kubespray-workers/           # AWS worker nodes module
|-- scripts/                             # Operational automation scripts
`-- docs/                                # Architecture & runbooks
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
