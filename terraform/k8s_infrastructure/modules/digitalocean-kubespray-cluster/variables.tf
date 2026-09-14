variable "enabled" {
  description = "Whether this DigitalOcean module is enabled. When false, no droplets, firewalls, or data sources are created."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Short cluster name used in labels and tags."
  type        = string
  default     = "kubespray"
}

variable "instance_name_prefix" {
  description = "Prefix used for DigitalOcean Droplet names."
  type        = string
  default     = "k8s"
}

variable "control_plane_count" {
  description = "Number of Kubernetes control plane nodes to create in DigitalOcean."
  type        = number
  default     = 0

  validation {
    condition     = var.control_plane_count >= 0 && floor(var.control_plane_count) == var.control_plane_count
    error_message = "control_plane_count must be a whole number that is 0 or greater."
  }
}

variable "control_plane_name_prefix" {
  description = "Kubespray inventory hostname prefix for control plane nodes."
  type        = string
  default     = "master"
}

variable "control_plane_index_offset" {
  description = "Starting offset for control plane node numbering (e.g., if master01 and master02 exist on GCP/AWS, offset by 2 so DigitalOcean starts at master03)."
  type        = number
  default     = 0
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes to create in DigitalOcean."
  type        = number
  default     = 0

  validation {
    condition     = var.worker_count >= 0 && floor(var.worker_count) == var.worker_count
    error_message = "worker_count must be a whole number that is 0 or greater."
  }
}

variable "worker_name_prefix" {
  description = "Kubespray inventory hostname prefix for worker nodes."
  type        = string
  default     = "worker"
}

variable "index_offset" {
  description = "Starting offset for worker node numbering (e.g., if worker01-04 exist on AWS, offset by 4 so DigitalOcean starts at worker05)."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------
# Concept 1: High Availability & Region Health (matching GCP & AWS)
# ---------------------------------------------------------------------------
variable "region" {
  description = "Primary DigitalOcean region (datacenter) slug (e.g. 'sgp1', 'nyc1', 'ams3', 'fra1')."
  type        = string
  default     = "sgp1"
}

variable "regions" {
  description = "Preferred DigitalOcean regions to spread droplets across (e.g. ['sgp1', 'blr1']). If empty, uses var.region or auto-discovers."
  type        = list(string)
  default     = []
}

variable "auto_discover_up_regions" {
  description = "When true, queries DigitalOcean API for available regions with available = true before building the node plan."
  type        = bool
  default     = true
}

variable "blocked_regions" {
  description = "DigitalOcean regions to skip/block if a region suffers from capacity or network issues."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Concept 2: Droplet Sizes & Stockout Fallbacks (matching GCP & AWS)
# ---------------------------------------------------------------------------
variable "control_plane_sizes" {
  description = "Primary Droplet slugs for control plane nodes by index. Reuses last value if more nodes than types."
  type        = list(string)
  default     = ["s-2vcpu-4gb", "s-4vcpu-8gb"]
}

variable "worker_sizes" {
  description = "Primary Droplet slugs for worker nodes by index (e.g. 's-2vcpu-4gb', 's-4vcpu-8gb', 'c-2')."
  type        = list(string)
  default     = ["s-2vcpu-4gb"]
}

variable "fallback_sizes" {
  description = "Fallback Droplet slugs to try if primary slug is in blocked_sizes."
  type        = list(string)
  default     = ["s-4vcpu-8gb", "s-2vcpu-2gb", "c-2", "g-2vcpu-8gb"]
}

variable "blocked_sizes" {
  description = "List of Droplet slugs to skip/block if DigitalOcean returns droplet size stockout."
  type        = list(string)
  default     = []
}

variable "random_resource_type" {
  description = "Allowed resource families (Standard, High CPU, High Memory) when selecting fallback sizes."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

# ---------------------------------------------------------------------------
# OS Image & Networking
# ---------------------------------------------------------------------------
variable "image" {
  description = "DigitalOcean Droplet image slug or image ID (e.g. 'ubuntu-24-04-x64')."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "vpc_uuid" {
  description = "The UUID of the DigitalOcean VPC to place Droplets in. If null, DigitalOcean places them in the region's default VPC."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Concept 4: Static Reserved IPs
# ---------------------------------------------------------------------------
variable "allocate_reserved_ips" {
  description = "Whether to allocate static Reserved IPs (Floating IPs) so public IPs never change across power-cycles."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Concept 5: Storage Architecture (Boot + Optional Secondary Block Storage)
# ---------------------------------------------------------------------------
variable "control_plane_data_disk_size_gb" {
  description = "Optional secondary DigitalOcean Block Storage Volume size in GB for persistent control plane storage. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "worker_data_disk_size_gb" {
  description = "Optional secondary DigitalOcean Block Storage Volume size in GB for persistent worker storage. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "worker_data_disk_filesystem" {
  description = "Initial filesystem type for secondary DigitalOcean Block Storage Volume."
  type        = string
  default     = "ext4"
}

# ---------------------------------------------------------------------------
# SSH & Node Credentials
# ---------------------------------------------------------------------------
variable "ssh_user" {
  description = "Linux SSH username configured on the DigitalOcean Droplets."
  type        = string
  default     = "seang"
}

variable "ssh_public_key" {
  description = "SSH public key content to install on DigitalOcean Droplets."
  type        = string
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to connect via SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_source_ranges" {
  description = "CIDR ranges allowed for Kubernetes cluster traffic (e.g. GCP/AWS control plane nodes, inter-node traffic)."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_cross_cluster_rule" {
  description = "Whether to allow all inter-node traffic from other cloud providers."
  type        = bool
  default     = true
}

variable "kubernetes_api_source_ranges" {
  description = "CIDR ranges allowed to access Kubernetes API Server (port 6443)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kubelet_source_ranges" {
  description = "Optional CIDR ranges allowed to access worker kubelet API (port 10250). Leave empty [] to keep internal-only."
  type        = list(string)
  default     = []
}

variable "wireguard_source_ranges" {
  description = "CIDR ranges allowed to connect to WireGuard VPN port 51820/udp."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "nodeport_source_ranges" {
  description = "CIDR ranges allowed to access NodePort range (30000-32767). Leave empty to disable rule."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Concept 8: Custom Firewall / Ingress Rules (matching GCP & AWS structure)
# ---------------------------------------------------------------------------
variable "custom_firewall_rules" {
  description = "Custom firewall rules matching GCP and AWS structure (e.g. allow HTTP/HTTPS)."
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
# Concepts 6 & 7: Power State, Exclude Nodes & Stop Nodes
# ---------------------------------------------------------------------------
variable "desired_status" {
  description = "Desired power state for instances: RUNNING or TERMINATED (stopped)."
  type        = string
  default     = "RUNNING"

  validation {
    condition     = contains(["RUNNING", "TERMINATED"], var.desired_status)
    error_message = "desired_status must be RUNNING or TERMINATED."
  }
}

variable "exclude_nodes" {
  description = "List of DigitalOcean instance names to permanently exclude (delete) from the cluster."
  type        = list(string)
  default     = []
}

variable "stop_nodes" {
  description = "List of DigitalOcean instance names to stop (power off) without deleting. Remaining active nodes continue running."
  type        = list(string)
  default     = []
}

variable "do_token" {
  description = "Optional DigitalOcean API Token used by power state automation scripts. If empty, falls back to DIGITALOCEAN_TOKEN env var."
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Additional DigitalOcean resource tags."
  type        = list(string)
  default     = []
}
