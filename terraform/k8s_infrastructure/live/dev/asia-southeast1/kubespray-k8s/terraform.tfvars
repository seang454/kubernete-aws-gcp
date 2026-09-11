# Backend Storage Toggle: set use_gcs_backend = true for GCS Cloud Storage, or false for Local Storage
use_gcs_backend  = false
gcs_bucket_name  = "project-469c6b81-55a1-4508-830-tfstate-bbdcad0e"
local_state_path = "../../../../state/dev/asia-southeast1/kubespray-k8s.tfstate"

project_id = "project-469c6b81-55a1-4508-830"
region     = "asia-east1"
zone       = "asia-east1-a"

# Kubespray cluster size.
control_plane_count = 3
worker_count        = 2
nfs_count           = 3

cluster_name         = "kubespray"
instance_name_prefix = "k8s"

# Inventory name prefixes
control_plane_name_prefix = "master"
worker_name_prefix        = "worker"
nfs_name_prefix           = "haproxy"

# Terraform spreads nodes across these zones in order (4 in asia-east1, 4 in asia-northeast1).
zones = [
  "asia-east1-a",
  "asia-east1-b",
  "asia-east1-c",
  "asia-northeast1-a",
  "asia-east1-a"
]

# Dedicated zones for NFS storage nodes in asia-northeast1
nfs_zones = [
  "asia-northeast1-a",
  "asia-northeast1-b",
  "asia-northeast1-c"
]

auto_discover_up_zones = true

fallback_regions = [
  "asia-east1"
]

blocked_zones         = []
blocked_regions       = []
blocked_machine_types = []

# Recommended: empty means Google automatically discovers ADC for whichever
# user runs Terraform after `gcloud auth application-default login`.
gcp_adc_file = ""

# Machine types are matched by node index.
control_plane_machine_types = [
  "e2-medium"
]

worker_machine_types = [
  "e2-medium"
]

nfs_machine_types = [
  "e2-medium"
]

fallback_machine_types = [
  "n1-standard-1",
  "e2-small",
  "g1-small"
]

random_resource_type = [
  "Standard",
  "High CPU",
  "High Memory"
]
# Desired VM power state: "RUNNING" to keep VMs powered on, "TERMINATED" to stop VMs.
desired_status = "RUNNING"

# ---------------------------------------------------------------------------
# Selective node deletion
# ---------------------------------------------------------------------------
# List specific GCP instance names to exclude (destroy) from the cluster.
# The node counts above define the full pool of names; this list filters out
# which ones actually get created. Remaining nodes keep their names/IPs/zones.
#
# Example: exclude_nodes = ["k8s-master02", "k8s-worker01", "k8s-haproxy-1", "k8s-haproxy-2"]
exclude_nodes = []

image                           = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
control_plane_boot_disk_size_gb = 20
worker_boot_disk_size_gb        = 20
nfs_boot_disk_size_gb           = 20
nfs_data_disk_size_gb           = 25
boot_disk_type                  = "pd-balanced"

network    = "default"
subnetwork = null

# SSH key Terraform puts on the VM metadata.
ssh_user            = "seang"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# SSH/private key values written into the inventories.
ansible_user                 = ""
ansible_ssh_private_key_file = "~/.ssh/id_rsa"
ansible_python_interpreter   = "/usr/bin/python3"
ansible_ssh_extra_args       = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Terraform writes the real VM IPs into Kubespray & Ansible inventories after apply.
kubespray_inventory_path   = "../../../../../ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini"
ansible_inventory_path     = "../../../../../ansible_kubespray_k8s/inventory.ini"
nfs_inventory_path         = "../../../../../../ansible-nfs-cluster-genesha/inventory/hosts.ini"

# For learning, this is open. For real use, restrict SSH/API to your public IP CIDR.
ssh_source_ranges            = ["0.0.0.0/0"]
kubernetes_api_source_ranges = ["0.0.0.0/0"]

# Internal node-to-node communication. Adjust this to your VPC/subnet CIDR in production.
internal_source_ranges = ["10.0.0.0/8"]

# Leave empty unless you intentionally expose Kubernetes NodePorts publicly.
# Network tags applied to every VM instance (enables default-allow-http and default-allow-https)
network_tags = ["http-server", "https-server"]

# ---------------------------------------------------------------------------
# Custom firewall rules
# ---------------------------------------------------------------------------
# Open HTTP (80) and HTTPS (443) on all cluster nodes for ingress controllers / web traffic.
custom_firewall_rules = [
  {
    name          = "allow-http-https"
    protocol      = "tcp"
    ports         = ["80", "443"]
    source_ranges = ["0.0.0.0/0"]
    target        = "all"
  }
]

