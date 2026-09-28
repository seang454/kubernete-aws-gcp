variable "name" {
  description = "Base name for the GCP VM instances. Terraform appends -1, -2, and so on. Use hyphens, not underscores."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.name))
    error_message = "name must be a valid GCP VM name prefix: lowercase letters, numbers, and hyphens only. It must start with a letter and cannot end with a hyphen."
  }
}

variable "enabled" {
  description = "When set to false, disables all GCP VM resources and queries completely."
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "Number of VM instances to create."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 0 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be a whole number that is 0 or greater."
  }
}

variable "allocate_static_ips" {
  description = "Whether to reserve and assign static external IPs. When false, instances receive dynamic/ephemeral public IPs from GCP to avoid static IP quota limits."
  type        = bool
  default     = true
}

variable "zone" {
  description = "Fallback GCP zone used when zones is empty."
  type        = string
}

variable "zones" {
  description = "List of GCP zones used to spread VMs. If empty, the module uses zone."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.zones) == 0 || alltrue([for zone in var.zones : trimspace(zone) != ""])
    error_message = "zones cannot contain empty strings."
  }
}

variable "auto_discover_up_zones" {
  description = "When true, Terraform asks GCP for zones with status UP before building the VM plan."
  type        = bool
  default     = true
}

variable "fallback_regions" {
  description = "Extra GCP regions Terraform may use when preferred zones are down or blocked."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for region in var.fallback_regions : trimspace(region) != ""])
    error_message = "fallback_regions cannot contain empty strings."
  }
}

variable "blocked_zones" {
  description = "GCP zones to skip after a zone is down or exhausted, for example asia-southeast1-a."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for zone in var.blocked_zones : trimspace(zone) != ""])
    error_message = "blocked_zones cannot contain empty strings."
  }
}

variable "blocked_regions" {
  description = "GCP regions to skip after a resource pool is exhausted, for example asia-southeast1."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for region in var.blocked_regions : trimspace(region) != ""])
    error_message = "blocked_regions cannot contain empty strings."
  }
}

variable "blocked_machine_types" {
  description = "GCP machine types to skip/block during stockout or quota limits."
  type        = list(string)
  default     = []
}

variable "machine_types" {
  description = "Machine types by VM index. If there are more VMs than values, Terraform reuses the last value."
  type        = list(string)
  default     = ["e2-standard-2"]

  validation {
    condition     = length(var.machine_types) > 0 && alltrue([for machine_type in var.machine_types : trimspace(machine_type) != ""])
    error_message = "machine_types must contain at least one non-empty machine type."
  }
}

variable "fallback_machine_types" {
  description = "Fallback machine types to try if primary machine type is unavailable."
  type        = list(string)
  default     = ["n2d-standard-2", "e2-highcpu-2", "e2-highmem-2", "n4-standard-2"]
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

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 30
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
  description = "GCP subnetwork name or self link. Leave null to use the network default."
  type        = string
  default     = null
}

variable "network_tags" {
  description = "Additional network tags for the VM."
  type        = list(string)
  default     = []
}

variable "ssh_user" {
  description = "Linux SSH username to add to instance metadata."
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

variable "public_service_ports" {
  description = "Public TCP ports exposed through the GCP firewall. The Ansible roles use Nginx on ports 80 and 443."
  type        = list(number)
  default     = [80, 443]

  validation {
    condition     = length(var.public_service_ports) > 0 && alltrue([for port in var.public_service_ports : port >= 1 && port <= 65535 && floor(port) == port])
    error_message = "public_service_ports must contain valid TCP port numbers from 1 through 65535."
  }
}

variable "public_service_source_ranges" {
  description = "CIDR ranges allowed to access public service ports such as HTTP and HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_service_ports" {
  description = "Optional TCP ports that must bypass Nginx, such as Jenkins inbound-agent port 50000. Backend localhost ports should not be added."
  type        = list(number)
  default     = []

  validation {
    condition     = alltrue([for port in var.additional_service_ports : port >= 1 && port <= 65535 && floor(port) == port])
    error_message = "additional_service_ports must contain valid TCP port numbers from 1 through 65535."
  }
}

variable "additional_service_source_ranges" {
  description = "Restricted CIDR ranges allowed to access additional service ports."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "GCP labels."
  type        = map(string)
  default     = {}
}
