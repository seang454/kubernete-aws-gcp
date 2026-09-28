variable "enabled" {
  description = "When set to false, disables all AWS VM resources completely."
  type        = bool
  default     = true
}

variable "name" {
  description = "Base name for AWS EC2 instances (e.g. 'aws-vm')."
  type        = string
  default     = "aws-vm"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_count" {
  description = "Number of AWS EC2 instances to create."
  type        = number
  default     = 0

  validation {
    condition     = var.instance_count >= 0 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be a whole number that is 0 or greater."
  }
}

variable "index_offset" {
  description = "Offset for numbering instance names (e.g., if offset is 1, instances are named aws-vm-2, aws-vm-3)."
  type        = number
  default     = 0
}

variable "vpc_id" {
  description = "Optional VPC ID. If null or empty, uses the default AWS VPC."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Explicit list of subnet IDs to place instances in. If empty, discovers default subnets in the VPC."
  type        = list(string)
  default     = []
}

variable "zones" {
  description = "List of preferred AWS availability zones, e.g. ['ap-southeast-1a', 'ap-southeast-1b']."
  type        = list(string)
  default     = []
}

variable "auto_discover_up_zones" {
  description = "Whether to discover available AWS availability zones dynamically."
  type        = bool
  default     = true
}

variable "blocked_zones" {
  description = "List of AWS availability zones to skip."
  type        = list(string)
  default     = []
}

variable "fallback_zones" {
  description = "Priority 2 AWS availability zones to use if preferred zones are unavailable or blocked."
  type        = list(string)
  default     = []
}

variable "machine_types" {
  description = "List of EC2 instance types (cycled or mapped by index), e.g. ['t4g.small'] or ['t3.medium']."
  type        = list(string)
  default     = ["t4g.small"]
}

variable "fallback_machine_types" {
  description = "Priority 2 fallback EC2 instance types if primary is blocked or unavailable."
  type        = list(string)
  default     = ["t4g.small", "t3.medium", "t3a.medium"]
}

variable "blocked_machine_types" {
  description = "List of EC2 instance types to skip/block (e.g. during stockout or quota limits)."
  type        = list(string)
  default     = []
}

variable "random_resource_type" {
  description = "Resource family preferences ('Standard', 'High CPU', 'High Memory') for Priority 3 dynamic selection."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "ami_id" {
  description = "Specific AMI ID. Leave empty to automatically discover official Ubuntu 24.04 LTS (Noble)."
  type        = string
  default     = ""
}

variable "boot_disk_size_gb" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 30
}

variable "boot_disk_type" {
  description = "Root EBS volume type (gp3, gp2, io1)."
  type        = string
  default     = "gp3"
}

variable "ssh_user" {
  description = "Default SSH user for connecting to the EC2 instances."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "OpenSSH public key content to install on the EC2 instances."
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file if ssh_public_key is empty."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allocate_elastic_ips" {
  description = "Whether to allocate static Elastic IPs for each EC2 instance."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "CIDR blocks allowed for SSH access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "public_service_ports" {
  description = "TCP ports for public web traffic (e.g. [80, 443])."
  type        = list(number)
  default     = [80, 443]
}

variable "public_service_source_ranges" {
  description = "CIDR blocks allowed for public service ports."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_service_ports" {
  description = "Direct-access backend service ports (e.g. [8000, 8080, 8081, 8082, 8200, 4954, 9000])."
  type        = list(number)
  default     = [8000, 8080, 8081, 8082, 8200, 4954, 9000]
}

variable "additional_service_source_ranges" {
  description = "CIDR blocks allowed for additional service ports."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Map of tags to assign to all AWS resources."
  type        = map(string)
  default = {
    environment = "dev"
    app         = "service-platform"
    managed_by  = "terraform"
  }
}
