variable "use_gcs_backend" {
  description = "Set to true to use Cloud GCS state storage, or false to use local state storage."
  type        = bool
  default     = false
}

variable "gcs_bucket_name" {
  description = "The GCS bucket name used when use_gcs_backend is true."
  type        = string
  default     = ""
}

variable "local_state_path" {
  description = "Custom local file path for storing Terraform state when use_gcs_backend is false."
  type        = string
  default     = "../../../../state/dev/asia-southeast1/kubespray-k8s.tfstate"
}

# ---------------------------------------------------------------------------
# GCP Settings
# ---------------------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "gcp_adc_file" {
  description = "Optional ADC JSON path. Leave empty for automatic per-user ADC discovery, or use ~ for the current user's home directory."
  type        = string
  default     = ""
  sensitive   = true
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "Fallback GCP zone used when zones is empty."
  type        = string
  default     = "asia-southeast1-a"
}

variable "zones" {
  description = "List of GCP zones used to spread Kubernetes nodes. If empty, Terraform uses zone."
  type        = list(string)
  default     = []
}

variable "auto_discover_up_zones" {
  description = "When true, Terraform asks GCP for zones with status UP before building the node plan."
  type        = bool
  default     = true
}

variable "fallback_regions" {
  description = "Extra GCP regions Terraform may use when preferred zones are down or blocked."
  type        = list(string)
  default     = []
}

variable "blocked_zones" {
  description = "GCP zones to skip after a zone is down or exhausted."
  type        = list(string)
  default     = []
}

variable "blocked_regions" {
  description = "GCP regions to skip after a resource pool is exhausted."
  type        = list(string)
  default     = []
}

variable "blocked_machine_types" {
  description = "List of machine types to skip/block if they suffer from GCP capacity stockouts or availability issues."
  type        = list(string)
  default     = []
}

variable "control_plane_machine_types" {
  description = "Machine types for GCP control plane nodes by index. If there are more nodes than values, Terraform reuses the last value."
  type        = list(string)
  default     = ["e2-medium"]
}

variable "worker_machine_types" {
  description = "Machine types for GCP worker nodes (if any) by index. If there are more nodes than values, Terraform reuses the last value."
  type        = list(string)
  default     = ["e2-medium"]
}

variable "fallback_machine_types" {
  description = "Fallback machine types to try if primary machine type is unavailable."
  type        = list(string)
  default     = ["n1-standard-1", "e2-medium", "e2-small", "g1-small"]
}

variable "random_resource_type" {
  description = "Allowed resource families (Standard, High CPU, High Memory) when selecting machine types."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "image" {
  description = "Boot disk image for GCP instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "control_plane_boot_disk_size_gb" {
  description = "Control plane boot disk size in GB."
  type        = number
  default     = 20
}

variable "worker_boot_disk_size_gb" {
  description = "GCP worker boot disk size in GB (if GCP workers deployed)."
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Boot disk type for GCP instances."
  type        = string
  default     = "pd-balanced"
}

variable "network" {
  description = "GCP VPC network name or self link."
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "GCP subnetwork name or self link. Leave null to use default behavior."
  type        = string
  default     = null
}

variable "network_tags" {
  description = "Additional GCP network tags to apply to every Kubernetes VM (e.g. http-server, https-server)."
  type        = list(string)
  default     = ["http-server", "https-server"]
}

variable "custom_firewall_rules" {
  description = "List of custom firewall rules to add to the cluster."
  type = list(object({
    name          = string
    protocol      = string
    ports         = list(string)
    source_ranges = list(string)
    target        = optional(string, "all")
  }))
  default = []
}

# ---------------------------------------------------------------------------
# AWS Settings
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for worker nodes."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile to use for authentication."
  type        = string
  default     = ""
}

variable "aws_shared_credentials_file" {
  description = "Optional custom path to AWS credentials file (e.g. '~/.aws/credentials' or a custom path). Leave empty for automatic discovery."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_shared_config_file" {
  description = "Optional custom path to AWS config file (e.g. '~/.aws/config' or a custom path). Leave empty for automatic discovery."
  type        = string
  default     = ""
}

variable "aws_access_key" {
  description = "Optional explicit AWS access key ID. If empty, uses AWS environment variables or profile."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "Optional explicit AWS secret access key. If empty, uses AWS environment variables or profile."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_session_token" {
  description = "Optional explicit AWS session token. If empty, uses AWS environment variables or profile."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_vpc_id" {
  description = "Optional AWS VPC ID. If null, uses the default VPC."
  type        = string
  default     = null
}

variable "aws_subnet_ids" {
  description = "Optional AWS subnet IDs. If empty, uses default VPC subnets."
  type        = list(string)
  default     = []
}

variable "aws_availability_zones" {
  description = "Optional availability zones in AWS to spread worker nodes across (e.g. ['ap-southeast-1a', 'ap-southeast-1b']). If empty, auto-discovers."
  type        = list(string)
  default     = []
}

variable "aws_auto_discover_up_zones" {
  description = "When true, asks AWS EC2 API for availability zones with state = 'available' before building the node plan."
  type        = bool
  default     = true
}

variable "aws_blocked_availability_zones" {
  description = "Optional AWS availability zones to skip/block if an AZ has capacity or availability issues."
  type        = list(string)
  default     = []
}

variable "aws_worker_machine_types" {
  description = "Primary AWS EC2 machine types for worker nodes."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "aws_worker_instance_types" {
  description = "Legacy alias for aws_worker_machine_types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "aws_fallback_machine_types" {
  description = "Fallback AWS EC2 instance types to try if primary machine type is in aws_blocked_machine_types."
  type        = list(string)
  default     = ["t3a.medium", "t2.medium", "m5.large"]
}

variable "aws_blocked_machine_types" {
  description = "List of AWS EC2 instance types to skip/block if AWS returns InsufficientInstanceCapacity."
  type        = list(string)
  default     = []
}

variable "aws_random_resource_type" {
  description = "Allowed AWS resource families (Standard, High CPU, High Memory) when selecting fallback machine types."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "aws_worker_ami_id" {
  description = "Optional explicit AWS AMI ID. If null, automatically resolves latest Ubuntu 24.04 LTS AMI."
  type        = string
  default     = null
}

variable "aws_worker_root_disk_size_gb" {
  description = "Root volume size in GB for AWS worker nodes."
  type        = number
  default     = 30
}

variable "aws_worker_root_disk_type" {
  description = "Root EBS volume type for AWS worker nodes."
  type        = string
  default     = "gp3"
}

variable "aws_worker_data_disk_size_gb" {
  description = "Optional secondary EBS data disk size in GB for persistent worker storage. Set 0 to disable."
  type        = number
  default     = 0
}

variable "aws_worker_data_disk_type" {
  description = "EBS volume type for secondary worker data disk."
  type        = string
  default     = "gp3"
}

variable "aws_allocate_elastic_ips" {
  description = "Allocate static Elastic IPs to AWS worker nodes so public IPs do not change on reboot/stop."
  type        = bool
  default     = true
}

variable "aws_vpc_cidr" {
  description = "CIDR range of the AWS VPC for cross-cloud firewall allow rules on GCP."
  type        = string
  default     = "172.31.0.0/16"
}

variable "aws_source_dest_check" {
  description = "Controls whether AWS checks source and destination IP addresses on worker instances. Must be false for Kubernetes CNI pod networking."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Cluster Topology & Node Counts
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "Short cluster name used in labels, firewall rules, and tags."
  type        = string
  default     = "kubespray"
}

variable "instance_name_prefix" {
  description = "Prefix used for VM instance names across both GCP and AWS."
  type        = string
  default     = "k8s"
}

variable "control_plane_count" {
  description = "Total or fallback control plane count. Kept for backwards compatibility."
  type        = number
  default     = 3
}

variable "gcp_control_plane_count" {
  description = "Number of Kubernetes control plane nodes on GCP (if null, uses control_plane_count)."
  type        = number
  default     = null
}

variable "aws_control_plane_count" {
  description = "Number of Kubernetes control plane nodes on AWS (default 0; can set 1, 2, etc. for cross-cloud multi-master)."
  type        = number
  default     = 0
}

variable "aws_control_plane_machine_types" {
  description = "EC2 instance types for AWS control plane nodes."
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "aws_control_plane_boot_disk_size_gb" {
  description = "Root EBS volume size in GB for AWS control plane nodes."
  type        = number
  default     = 50
}

variable "aws_worker_count" {
  description = "Number of Kubernetes worker nodes to create on AWS."
  type        = number
  default     = 4
}

variable "gcp_worker_count" {
  description = "Number of Kubernetes worker nodes to create on GCP (default 0 when workers run on AWS)."
  type        = number
  default     = 0
}

variable "worker_count" {
  description = "Legacy variable for worker count. Kept for backwards compatibility."
  type        = number
  default     = 0
}

variable "control_plane_name_prefix" {
  description = "Kubespray inventory hostname prefix for control plane nodes."
  type        = string
  default     = "master"
}

variable "worker_name_prefix" {
  description = "Kubespray inventory hostname prefix for worker nodes."
  type        = string
  default     = "worker"
}

# ---------------------------------------------------------------------------
# Cross-cloud Networking & Kubespray Inventory Settings
# ---------------------------------------------------------------------------
variable "use_wireguard_ip" {
  description = "Assign WireGuard full-mesh overlay IPs (10.0.0.1 - 10.0.0.x) to ip and access_ip in Kubespray inventory for encrypted cross-cloud Kubernetes traffic over wg0."
  type        = bool
  default     = true
}

variable "use_public_access_ip" {
  description = "Set access_ip = public_ip in the Kubespray inventory for seamless cross-cloud communication without a private VPN. Set false if using VPN/Interconnect."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to connect to SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "internal_source_ranges" {
  description = "CIDR ranges allowed for internal Kubernetes node-to-node traffic."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "kubernetes_api_source_ranges" {
  description = "CIDR ranges allowed to connect to the Kubernetes API server on 6443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "wireguard_source_ranges" {
  description = "CIDR ranges allowed to connect to WireGuard VPN port 51820/udp. Defaults to ['0.0.0.0/0'] for multi-cloud mesh."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kubelet_source_ranges" {
  description = "Optional CIDR ranges allowed to access worker kubelet API (port 10250). Leave empty [] to keep internal-only (recommended)."
  type        = list(string)
  default     = []
}

variable "nodeport_source_ranges" {
  description = "Optional CIDR ranges allowed to connect to NodePort range 30000-32767. Leave empty to skip."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# SSH & Ansible Credentials
# ---------------------------------------------------------------------------
variable "ssh_user" {
  description = "Linux SSH username configured on both GCP and AWS VMs."
  type        = string
  default     = "seang"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key. If this file and ansible_ssh_private_key_file do not exist, Terraform generates them."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ansible_user" {
  description = "Ansible SSH user written into the inventory. Leave empty to reuse ssh_user."
  type        = string
  default     = ""
}

variable "ansible_ssh_private_key_file" {
  description = "SSH private key path written into the Kubespray inventory."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ansible_python_interpreter" {
  description = "Python interpreter path written into the Kubespray inventory."
  type        = string
  default     = "/usr/bin/python3"
}

variable "ansible_ssh_extra_args" {
  description = "Extra SSH options written into the Kubespray inventory."
  type        = string
  default     = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}

variable "kubespray_inventory_path" {
  description = "Path where Terraform writes the generated Kubespray inventory file."
  type        = string
  default     = "../../../../../ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini"
}

variable "ansible_inventory_path" {
  description = "Path where Terraform writes the generated Ansible inventory for playbooks."
  type        = string
  default     = "../../../../../ansible_kubespray_k8s/inventory.ini"
}

variable "wireguard_inventory_path" {
  description = "Path where Terraform writes the generated WireGuard Ansible inventory file."
  type        = string
  default     = "../../../../../wiregurad/inventory/hosts.ini"
}

# ---------------------------------------------------------------------------
# Power State & Selective Deletion
# ---------------------------------------------------------------------------
variable "desired_status" {
  description = "Desired VM power state: RUNNING to keep VMs powered on, TERMINATED to stop VMs across both GCP and AWS."
  type        = string
  default     = "RUNNING"

  validation {
    condition     = contains(["RUNNING", "TERMINATED"], var.desired_status)
    error_message = "desired_status must be RUNNING or TERMINATED."
  }
}

variable "exclude_nodes" {
  description = "List of instance names to permanently exclude (delete/destroy) from the cluster (e.g. k8s-master01, k8s-worker01). When removed from exclude_nodes, the machine and its resources are created/recreated."
  type        = list(string)
  default     = []
}

variable "stop_nodes" {
  description = "List of instance names to stop (power off) without deleting (e.g. k8s-master02, k8s-worker03). When removed from stop_nodes, the machine powers back on (starts running)."
  type        = list(string)
  default     = []
}

variable "exclude_stopped_nodes_from_inventory" {
  description = "When true, stopped nodes are excluded from the Kubespray inventory so playbooks do not time out trying to connect to powered-off VMs. Set false to keep all created nodes in the inventory."
  type        = bool
  default     = true
}
