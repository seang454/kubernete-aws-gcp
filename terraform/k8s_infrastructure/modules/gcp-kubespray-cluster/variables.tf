variable "cluster_name" {
  description = "Short cluster name used in labels and firewall names."
  type        = string
  default     = "kubespray"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must use lowercase letters, numbers, and hyphens. It must start with a letter and cannot end with a hyphen."
  }
}

variable "instance_name_prefix" {
  description = "Prefix used for GCP VM instance names."
  type        = string
  default     = "k8s"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.instance_name_prefix))
    error_message = "instance_name_prefix must use lowercase letters, numbers, and hyphens. It must start with a letter and cannot end with a hyphen."
  }
}

variable "control_plane_count" {
  description = "Number of Kubernetes control plane nodes to create."
  type        = number
  default     = 3

  validation {
    condition     = var.control_plane_count >= 1 && floor(var.control_plane_count) == var.control_plane_count
    error_message = "control_plane_count must be a whole number that is 1 or greater."
  }
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes to create."
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 0 && floor(var.worker_count) == var.worker_count
    error_message = "worker_count must be a whole number that is 0 or greater."
  }
}

variable "nfs_count" {
  description = "Number of NFS/Ceph storage nodes to create."
  type        = number
  default     = 3

  validation {
    condition     = var.nfs_count >= 0 && floor(var.nfs_count) == var.nfs_count
    error_message = "nfs_count must be a whole number that is 0 or greater."
  }
}

variable "control_plane_name_prefix" {
  description = "Inventory hostname prefix for control plane nodes."
  type        = string
  default     = "master"
}

variable "worker_name_prefix" {
  description = "Inventory hostname prefix for worker nodes."
  type        = string
  default     = "worker"
}

variable "nfs_name_prefix" {
  description = "Inventory hostname prefix for NFS storage nodes."
  type        = string
  default     = "haproxy"
}

variable "nfs_machine_types" {
  description = "Machine types for NFS storage nodes by index."
  type        = list(string)
  default     = ["e2-standard-2"]
}

variable "nfs_boot_disk_size_gb" {
  description = "NFS node boot disk size in GB."
  type        = number
  default     = 50
}

variable "nfs_data_disk_size_gb" {
  description = "NFS node secondary data disk size in GB for Ceph OSD."
  type        = number
  default     = 50
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

variable "nfs_zones" {
  description = "Optional explicit GCP zones for NFS storage nodes to pin persistent data disks to their existing zones."
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
  description = "Machine types for control plane nodes by index. If there are more nodes than values, Terraform reuses the last value."
  type        = list(string)
  default     = ["e2-standard-2"]

  validation {
    condition     = length(var.control_plane_machine_types) > 0 && alltrue([for machine_type in var.control_plane_machine_types : trimspace(machine_type) != ""])
    error_message = "control_plane_machine_types must contain at least one non-empty machine type."
  }
}

variable "worker_machine_types" {
  description = "Machine types for worker nodes by index. If there are more nodes than values, Terraform reuses the last value."
  type        = list(string)
  default     = ["e2-standard-2"]

  validation {
    condition     = length(var.worker_machine_types) > 0 && alltrue([for machine_type in var.worker_machine_types : trimspace(machine_type) != ""])
    error_message = "worker_machine_types must contain at least one non-empty machine type."
  }
}

variable "fallback_machine_types" {
  description = "Fallback machine types to try if primary machine type is unavailable."
  type        = list(string)
  default     = ["n1-standard-1", "e2-medium", "e2-small", "g1-small"]
}

variable "max_fallback_machine_cpus" {
  description = "Maximum vCPU size allowed for fallback machine types (e.g., 2 or 4) to prevent exceeding GCP project quota limits."
  type        = number
  default     = 4
}

variable "random_resource_type" {
  description = "Allowed resource families (Standard, High CPU, High Memory) when selecting machine types."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "desired_status" {
  description = "Desired VM power state. RUNNING keeps Terraform-managed VMs up; TERMINATED stops them."
  type        = string
  default     = "RUNNING"

  validation {
    condition     = contains(["RUNNING", "TERMINATED"], var.desired_status)
    error_message = "desired_status must be RUNNING or TERMINATED."
  }
}

variable "image" {
  description = "Boot disk image."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "control_plane_boot_disk_size_gb" {
  description = "Control plane boot disk size in GB."
  type        = number
  default     = 50
}

variable "worker_boot_disk_size_gb" {
  description = "Worker boot disk size in GB."
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Boot disk type."
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

variable "ssh_user" {
  description = "Linux SSH username."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Fallback path to the SSH public key when ssh_public_key is empty. A leading ~ uses the current Terraform user's home directory."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_public_key" {
  description = "SSH public key content to add to GCP VM metadata. When empty, ssh_public_key_path is read instead."
  type        = string
  default     = ""
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

variable "nodeport_source_ranges" {
  description = "Optional CIDR ranges allowed to connect to Kubernetes NodePort range 30000-32767. Leave empty to skip this firewall rule."
  type        = list(string)
  default     = []
}

variable "network_tags" {
  description = "Additional GCP network tags to apply to every Kubernetes VM."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Additional labels to add to every VM."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Selective node deletion
# ---------------------------------------------------------------------------
variable "exclude_nodes" {
  description = "List of GCP instance names to exclude (delete) from the cluster. Names must match the full instance name with prefix (e.g. k8s-master01, k8s-worker02, k8s-haproxy-1). Excluded nodes and their resources (VM, static IP, data disks) are destroyed while remaining nodes stay untouched."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Custom firewall rules
# ---------------------------------------------------------------------------
# Each entry creates one google_compute_firewall resource that opens the
# specified ports for the given protocol and source CIDR ranges.
#
# Example (in terraform.tfvars):
#
#   custom_firewall_rules = [
#     {
#       name          = "http"
#       protocol      = "tcp"
#       ports         = ["80", "443"]
#       source_ranges = ["0.0.0.0/0"]
#       target        = "all"   # "all" | "control_plane" | "worker"
#     },
#     {
#       name          = "nodeexporter"
#       protocol      = "tcp"
#       ports         = ["9100"]
#       source_ranges = ["10.0.0.0/8"]
#       target        = "all"
#     },
#   ]
variable "custom_firewall_rules" {
  description = "List of custom firewall rules to add to the cluster. Each rule opens one or more ports for a given protocol and set of source CIDR ranges. Set target to 'all', 'control_plane', or 'worker' to scope the rule."
  type = list(object({
    name          = string
    protocol      = string
    ports         = list(string)
    source_ranges = list(string)
    target        = optional(string, "all")
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.custom_firewall_rules :
      contains(["all", "control_plane", "worker"], coalesce(rule.target, "all"))
    ])
    error_message = "Each custom_firewall_rules entry target must be 'all', 'control_plane', or 'worker'."
  }
}
