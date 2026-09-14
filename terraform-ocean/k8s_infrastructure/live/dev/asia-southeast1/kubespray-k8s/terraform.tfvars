# Backend Storage Toggle: set use_gcs_backend = true for GCS Cloud Storage, or false for Local Storage
use_gcs_backend  = false
gcs_bucket_name  = "project-469c6b81-55a1-4508-830-tfstate-bbdcad0e"
local_state_path = "../../../../state/dev/asia-southeast1/kubespray-k8s.tfstate"

# ---------------------------------------------------------------------------
# Cloud Provider Activation Toggles
# ---------------------------------------------------------------------------
# Toggle which cloud providers are active. When set to false, Terraform will
# completely bypass that provider, creating 0 nodes, skipping data queries,
# and avoiding any cloud API calls or credential errors for that cloud.
enable_gcp          = true
enable_aws          = true
enable_digitalocean = false

# ---------------------------------------------------------------------------
# GCP Configuration
# ---------------------------------------------------------------------------
project_id = "project-469c6b81-55a1-4508-830"
region     = "asia-east1"
zone       = "asia-east1-a"

# Recommended: empty means Google automatically discovers ADC for whichever
# user runs Terraform after `gcloud auth application-default login`.
gcp_adc_file = "/home/seang/.config/gcloud/application_default_credentials.json"

# Terraform spreads nodes across these zones in order.
zones = [
  "asia-east1-a",
  "asia-east1-b",
  "asia-east1-c",
  "asia-northeast1-a",
  "asia-east1-a"
]

auto_discover_up_zones = true

fallback_regions = [
  "asia-east1"
]

blocked_zones         = []
blocked_regions       = []
blocked_machine_types = []

# Machine types for GCP nodes
control_plane_machine_types = [
  "e2-medium"
]

worker_machine_types = [
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

image                           = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
control_plane_boot_disk_size_gb = 50
worker_boot_disk_size_gb        = 50
boot_disk_type                  = "pd-balanced"

network    = "default"
subnetwork = null

# ---------------------------------------------------------------------------
# AWS Configuration
# ---------------------------------------------------------------------------
# AWS Configuration (Full Parity with GCP Error Handling)
# ---------------------------------------------------------------------------
aws_region  = "ap-southeast-1"
aws_profile = ""

# Recommended: empty ("") means AWS automatically discovers credentials from
# ~/.aws/credentials or environment variables. You can set a custom path:
# e.g. aws_shared_credentials_file = "~/.aws/credentials"
# e.g. aws_shared_credentials_file = "/home/seang/secrets/my_aws_credentials"
aws_shared_credentials_file    = ""
aws_shared_config_file         = ""
aws_availability_zones         = []
aws_auto_discover_up_zones     = true
aws_blocked_availability_zones = []

# Machine types for AWS nodes (conforms to AWS Account tier restrictions)
aws_control_plane_machine_types = ["t3.small"]
aws_worker_machine_types        = ["t3.small"]
aws_fallback_machine_types      = ["t3.small", "t3.micro"]
aws_blocked_machine_types       = []
aws_random_resource_type        = ["Standard", "High CPU", "High Memory"]

# Storage (50 GB for both Master and Worker nodes)
aws_control_plane_boot_disk_size_gb = 50 # master03 (AWS Master)
aws_worker_root_disk_size_gb        = 50 # worker01..worker04 (AWS Workers)
aws_worker_root_disk_type           = "gp3"
aws_worker_data_disk_size_gb        = 0 # Set > 0 for optional secondary EBS volume (/dev/sdb)
aws_worker_data_disk_type           = "gp3"

# Networking & IPs
aws_allocate_elastic_ips = true
aws_vpc_cidr             = "172.31.0.0/16"
aws_source_dest_check    = false

# ---------------------------------------------------------------------------
# DigitalOcean Configuration (Full Parity with GCP & AWS)
# ---------------------------------------------------------------------------
# Recommended: leave do_token empty ("") and export DIGITALOCEAN_TOKEN in shell.
# Or set explicitly: do_token = "dop_v1_xxxx"
do_token                              = ""
digitalocean_region                   = "sgp1"
digitalocean_regions                  = []
digitalocean_auto_discover_up_regions = true
digitalocean_blocked_regions          = []

# Machine types (droplet sizes) for DigitalOcean nodes
digitalocean_control_plane_sizes  = ["s-2vcpu-4gb", "s-4vcpu-8gb"]
digitalocean_worker_sizes         = ["s-2vcpu-4gb"]
digitalocean_fallback_sizes       = ["s-4vcpu-8gb", "s-2vcpu-2gb", "c-2", "g-2vcpu-8gb"]
digitalocean_blocked_sizes        = []
digitalocean_random_resource_type = ["Standard", "High CPU", "High Memory"]

# Networking & Reserved IPs
digitalocean_image                 = "ubuntu-24-04-x64"
digitalocean_vpc_uuid              = null
digitalocean_allocate_reserved_ips = true

# Storage (Optional secondary block storage volumes for Master and Worker nodes)
# Note: DigitalOcean Droplets already include 80 GB SSD boot disk automatically in size 's-2vcpu-4gb'!
digitalocean_control_plane_data_disk_size_gb = 0 # Set > 0 for master secondary block storage volume
digitalocean_worker_data_disk_size_gb        = 0 # Set > 0 for worker secondary block storage volume

# ---------------------------------------------------------------------------
# Dynamic Multi-Cloud Node Topology (GCP, AWS, and DigitalOcean)
# ---------------------------------------------------------------------------
# Customize any combination of control plane (master) and worker nodes:
# - All on DigitalOcean: gcp_control_plane_count = 0, aws_control_plane_count = 0, digitalocean_control_plane_count = 3, digitalocean_worker_count = 3
# - Masters on DO, Workers on AWS: digitalocean_control_plane_count = 3, aws_worker_count = 4
# - Tri-Cloud HA Quorum: gcp_control_plane_count = 1, aws_control_plane_count = 1, digitalocean_control_plane_count = 1
# - Split Workers:       gcp_worker_count = 2, aws_worker_count = 2, digitalocean_worker_count = 2
# ---------------------------------------------------------------------------
gcp_control_plane_count          = 2
aws_control_plane_count          = 1
digitalocean_control_plane_count = 0 # Set to 1, 2, or 3 for DigitalOcean master nodes!

gcp_worker_count          = 0
aws_worker_count          = 4
digitalocean_worker_count = 0 # Set to 2, 4 for DigitalOcean worker nodes!

cluster_name         = "kubespray"
instance_name_prefix = "k8s"

# Inventory name prefixes
control_plane_name_prefix = "master"
worker_name_prefix        = "worker"

# Use WireGuard full-mesh overlay IPs (10.0.0.1 - 10.0.0.x) for Kubespray cluster traffic
use_wireguard_ip = true

# Cross-cloud network mode: fallback when use_wireguard_ip is false
use_public_access_ip = true

# Desired VM power state: "RUNNING" to keep VMs powered on, "TERMINATED" to stop VMs.
desired_status = "RUNNING"

# ---------------------------------------------------------------------------
# Selective Node Deletion (Destroy / Create)
# ---------------------------------------------------------------------------
# List specific instance names to permanently delete/destroy across GCP and AWS.
# When a node is removed from exclude_nodes, Terraform automatically creates/recreates it.
# Example: exclude_nodes = ["k8s-master02", "k8s-worker04"]
exclude_nodes = []

# ---------------------------------------------------------------------------
# Selective Node Stopping (Power Off / Power On)
# ---------------------------------------------------------------------------
# List specific instance names to stop (power off) without deleting their VM, disks, or IP.
# When a node is removed from stop_nodes, Terraform automatically starts/powers it back on.
# Example: stop_nodes = ["k8s-worker03", "k8s-worker04"]
stop_nodes = []

# Exclude stopped nodes from Kubespray inventory to prevent SSH timeouts on powered-off nodes
exclude_stopped_nodes_from_inventory = true

# ---------------------------------------------------------------------------
# SSH & Ansible Settings
# ---------------------------------------------------------------------------
# SSH key Terraform puts on both GCP VM metadata and AWS key pairs.
ssh_user            = "seang"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# SSH/private key values written into the inventories.
# [CLIENT-SIDE KEEP-ALIVE]: Tells your local SSH client/Ansible to ping the remote
# servers every 30s so NAT firewalls do not drop idle connections during long plays.
ansible_user                 = ""
ansible_ssh_private_key_file = "~/.ssh/id_rsa"
ansible_python_interpreter   = "/usr/bin/python3"
ansible_ssh_extra_args       = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o TCPKeepAlive=yes"

# Inventory paths
kubespray_inventory_path     = "../../../../../ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini"
ansible_inventory_path       = "../../../../../ansible_kubespray_k8s/inventory.ini"
increase_disk_inventory_path = "../../../../../increase-disk-alignment/inventory.ini"

# ---------------------------------------------------------------------------
# Firewall and Security Group Access (Unified Single-List Pattern)
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Internal Private Cluster Subnet (WireGuard + Kubernetes Pods + Services)
# ---------------------------------------------------------------------------
# 10.0.0.0/8 is the private IP range that allows ALL internal cluster traffic
# to flow freely through the encrypted WireGuard VPN tunnel without public internet exposure.
# This single range covers:
#   • WireGuard Node IPs:      10.0.0.1 – 10.0.0.7 (cross-cloud node mesh)
#   • Kubernetes Pod Network:  10.233.64.0/18 (Calico/Flannel pod-to-pod routing)
#   • Kubernetes Service IPs:  10.233.0.0/18 (Internal ClusterIPs & CoreDNS)
#   • etcd Quorum (2379-2380) & Kubelet API (10250) inter-node communication
# CRITICAL: Do NOT delete or set to [] — without this, nodes cannot talk to each other!
internal_source_ranges = ["10.0.0.0/8"]

# Network tags applied to every GCP VM instance
network_tags = ["http-server", "https-server"]

# Set to [] when managing via custom_firewall_rules below
ssh_source_ranges            = []
kubernetes_api_source_ranges = []
wireguard_source_ranges      = []
kubelet_source_ranges        = []
nodeport_source_ranges       = []

# ---------------------------------------------------------------------------
# All Open Ports Defined in One Clean, Central List
# Easily add, remove, or modify ports across both GCP and AWS!
# ---------------------------------------------------------------------------
custom_firewall_rules = [
  {
    name          = "allow-ssh"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["0.0.0.0/0"]
    target        = "all"
  },
  {
    name          = "allow-wireguard"
    protocol      = "udp"
    ports         = ["51820"]
    source_ranges = ["0.0.0.0/0"]
    target        = "all"
  },
  {
    name          = "allow-kube-api"
    protocol      = "tcp"
    ports         = ["6443"]
    source_ranges = ["0.0.0.0/0"]
    target        = "control_plane"
  },
  {
    name          = "allow-http-https"
    protocol      = "tcp"
    ports         = ["80", "443"]
    source_ranges = ["0.0.0.0/0"]
    target        = "all"
  }
]
