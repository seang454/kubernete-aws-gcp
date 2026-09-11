variable "cluster_name" {
  description = "Short cluster name used in labels and tags."
  type        = string
  default     = "kubespray"
}

variable "instance_name_prefix" {
  description = "Prefix used for AWS EC2 instance names."
  type        = string
  default     = "k8s"
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes to create in AWS."
  type        = number
  default     = 4

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
  description = "Starting offset for worker node numbering (e.g., if 2 GCP workers exist, offset by 2 so AWS starts at worker03)."
  type        = number
  default     = 0
}

variable "aws_region" {
  description = "AWS region for worker node deployment."
  type        = string
  default     = "ap-southeast-1"
}

# ---------------------------------------------------------------------------
# Concept 1: High Availability & Zone Health (matching GCP)
# ---------------------------------------------------------------------------
variable "zones" {
  description = "Preferred AWS availability zones to spread worker nodes across (e.g. ['ap-southeast-1a', 'ap-southeast-1b']). If empty, auto-discovers."
  type        = list(string)
  default     = []
}

variable "auto_discover_up_zones" {
  description = "When true, asks AWS EC2 API for availability zones with state = 'available' before building the node plan."
  type        = bool
  default     = true
}

variable "blocked_zones" {
  description = "AWS availability zones to skip/block if an AZ suffers from capacity or availability issues."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Concept 2: Machine Types & Stockout Fallbacks (matching GCP)
# ---------------------------------------------------------------------------
variable "worker_machine_types" {
  description = "Primary EC2 instance types for worker nodes by index. Reuses last value if more nodes than types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "fallback_machine_types" {
  description = "Fallback EC2 instance types to try if primary machine type is in blocked_machine_types."
  type        = list(string)
  default     = ["t3a.medium", "t2.medium", "m5.large"]
}

variable "blocked_machine_types" {
  description = "List of EC2 instance types to skip/block if AWS returns InsufficientInstanceCapacity."
  type        = list(string)
  default     = []
}

variable "random_resource_type" {
  description = "Allowed resource families (Standard, High CPU, High Memory) when selecting fallback machine types."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

# ---------------------------------------------------------------------------
# Networking, VPC & AMI
# ---------------------------------------------------------------------------
variable "vpc_id" {
  description = "AWS VPC ID where worker nodes will be created. If null or empty, uses the default VPC."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of AWS subnet IDs to place worker nodes in. If empty, uses subnets from the resolved VPC."
  type        = list(string)
  default     = []
}

variable "ami_id" {
  description = "Explicit AWS AMI ID. If null, automatically discovers the latest official Canonical Ubuntu 24.04 LTS AMI."
  type        = string
  default     = null
}

variable "source_dest_check" {
  description = "Controls if traffic is checked on the instance. Must be false for Kubernetes CNI pod networking."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Concept 5: Storage Architecture (Boot + Optional Secondary EBS Data Volume)
# ---------------------------------------------------------------------------
variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "worker_data_disk_size_gb" {
  description = "Optional secondary EBS data volume size in GB for persistent worker storage. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "worker_data_disk_type" {
  description = "EBS volume type for secondary data disk."
  type        = string
  default     = "gp3"
}

# ---------------------------------------------------------------------------
# SSH & Node Credentials
# ---------------------------------------------------------------------------
variable "ssh_user" {
  description = "Linux SSH username configured on the worker instances."
  type        = string
  default     = "seang"
}

variable "ssh_public_key" {
  description = "SSH public key content to install on worker instances."
  type        = string
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to connect via SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_source_ranges" {
  description = "CIDR ranges allowed for Kubernetes cluster traffic (e.g. GCP control plane nodes, inter-node traffic)."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_cross_cluster_rule" {
  description = "Whether to create the cross-cluster ingress security group rule."
  type        = bool
  default     = true
}

variable "kubernetes_api_source_ranges" {
  description = "CIDR ranges allowed to access worker kubelet API (port 10250)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "nodeport_source_ranges" {
  description = "CIDR ranges allowed to access NodePort range (30000-32767). Leave empty to disable rule."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Concept 8: Custom Firewall / Ingress Rules (matching GCP structure)
# ---------------------------------------------------------------------------
variable "custom_firewall_rules" {
  description = "Custom firewall rules matching GCP structure (e.g. allow HTTP/HTTPS). Automatically filtered for worker nodes."
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
# Concepts 4 & 6: Power State & Static Elastic IPs
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

variable "allocate_elastic_ips" {
  description = "Whether to allocate static Elastic IPs so worker public IPs do not change across stop/start cycles."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Concept 7: Selective Node Deletion
# ---------------------------------------------------------------------------
variable "exclude_nodes" {
  description = "List of AWS instance names to exclude (delete) from the cluster."
  type        = list(string)
  default     = []
}

variable "stop_nodes" {
  description = "List of AWS instance names to stop (power off) without deleting (e.g. ['k8s-worker03', 'k8s-worker04']). Remaining active nodes continue running. When removed from stop_nodes, VMs power back on."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional AWS resource tags."
  type        = map(string)
  default     = {}
}
