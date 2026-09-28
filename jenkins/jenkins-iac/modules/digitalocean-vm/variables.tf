variable "enabled" {
  description = "When set to false, disables all DigitalOcean VM resources completely."
  type        = bool
  default     = false
}

variable "name" {
  description = "Base name for DigitalOcean Droplets (e.g. 'do-vm')."
  type        = string
  default     = "do-vm"
}

variable "instance_count" {
  description = "Number of DigitalOcean Droplets to create."
  type        = number
  default     = 0

  validation {
    condition     = var.instance_count >= 0 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be a whole number that is 0 or greater."
  }
}

variable "index_offset" {
  description = "Offset for numbering instance names."
  type        = number
  default     = 0
}

variable "region" {
  description = "Primary DigitalOcean datacenter region (e.g. 'sgp1', 'nyc1')."
  type        = string
  default     = "sgp1"
}

variable "regions" {
  description = "List of DigitalOcean regions to cycle across."
  type        = list(string)
  default     = []
}

variable "auto_discover_up_regions" {
  description = "Whether to query DigitalOcean API for available regions."
  type        = bool
  default     = true
}

variable "blocked_regions" {
  description = "List of DigitalOcean regions to avoid."
  type        = list(string)
  default     = []
}

variable "fallback_regions" {
  description = "Priority 2 fallback DigitalOcean regions to use if primary region is unavailable or blocked."
  type        = list(string)
  default     = []
}

variable "image" {
  description = "DigitalOcean distribution image slug."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "sizes" {
  description = "List of Droplet sizes, e.g. ['s-2vcpu-4gb']."
  type        = list(string)
  default     = ["s-2vcpu-4gb"]
}

variable "fallback_sizes" {
  description = "Priority 2 fallback Droplet sizes if primary is unavailable."
  type        = list(string)
  default     = ["s-2vcpu-2gb", "s-4vcpu-8gb"]
}

variable "blocked_sizes" {
  description = "List of Droplet sizes to skip/block."
  type        = list(string)
  default     = []
}

variable "random_resource_type" {
  description = "Resource family preferences ('Standard', 'High CPU', 'High Memory') for Priority 3 dynamic selection."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "ssh_user" {
  description = "SSH user for Droplet connection."
  type        = string
  default     = "root"
}

variable "ssh_public_key" {
  description = "OpenSSH public key content."
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allocate_reserved_ips" {
  description = "Whether to assign static Reserved IPs (Floating IPs) to Droplets."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed for SSH access."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "public_service_ports" {
  description = "TCP ports for public web traffic."
  type        = list(number)
  default     = [80, 443]
}

variable "public_service_source_ranges" {
  description = "CIDR blocks allowed for public web traffic."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "additional_service_ports" {
  description = "Additional service backend ports."
  type        = list(number)
  default     = [8000, 8080, 8081, 8082, 8200, 4954, 9000]
}

variable "additional_service_source_ranges" {
  description = "CIDR blocks allowed for additional ports."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "tags" {
  description = "Tags to assign to Droplets."
  type        = list(string)
  default     = ["dev", "service-platform", "managed-by-terraform"]
}
