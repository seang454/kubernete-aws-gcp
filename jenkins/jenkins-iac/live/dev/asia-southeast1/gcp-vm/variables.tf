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

variable "instance_count" {
  description = "Number of VM instances to create (default fallback if cloud-specific count is null)."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 0 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be a whole number that is 0 or greater."
  }
}

variable "zones" {
  description = "List of GCP zones used to spread VMs. If empty, Terraform uses zone."
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

variable "name" {
  description = "Base VM instance name. Terraform appends -1, -2, and so on. Use hyphens, not underscores."
  type        = string
  default     = "gcp-vm"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.name))
    error_message = "name must be a valid GCP VM name prefix: lowercase letters, numbers, and hyphens only. It must start with a letter and cannot end with a hyphen."
  }
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
  description = "Path to the SSH public key. If this file and ansible_ssh_private_key_path do not exist, Terraform generates them. A leading ~ uses the current Terraform user's home directory."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to connect to SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "public_service_ports" {
  description = "Public TCP ports exposed through the GCP firewall. The Ansible service roles use Nginx on ports 80 and 443."
  type        = list(number)
  default     = [80, 443]

  validation {
    condition     = length(var.public_service_ports) > 0 && alltrue([for port in var.public_service_ports : port >= 1 && port <= 65535 && floor(port) == port])
    error_message = "public_service_ports must contain valid TCP port numbers from 1 through 65535."
  }
}

variable "public_service_source_ranges" {
  description = "CIDR ranges allowed to access public service ports."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_service_ports" {
  description = "Optional TCP ports that bypass Nginx, such as Jenkins inbound-agent port 50000."
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

variable "ansible_inventory_path" {
  description = "Path where Terraform writes the generated Ansible inventory file."
  type        = string
  default     = "../../../../../ansible_service_config/inventories/dev/hosts.ini"
}

variable "ansible_inventory_groups" {
  description = "Fallback Ansible inventory groups that receive all Terraform-created VMs when no dynamic service targets are available."
  type        = list(string)
  default     = ["sonarqube"]

  validation {
    condition     = length(var.ansible_inventory_groups) > 0 && alltrue([for group in var.ansible_inventory_groups : can(regex("^[A-Za-z0-9_-]+$", group))])
    error_message = "ansible_inventory_groups must contain at least one valid Ansible group name."
  }
}

variable "ansible_service_targets" {
  description = "Optional explicit Ansible service groups mapped to one VM index. If empty, Terraform can derive groups from Cloudflare A/AAAA records when Cloudflare DNS is enabled."
  type = map(object({
    vm_index = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for group, target in var.ansible_service_targets :
      can(regex("^[A-Za-z0-9_-]+$", group)) && (try(target.vm_index, null) == null || try(target.vm_index >= 0, false))
    ])
    error_message = "ansible_service_targets keys must be valid Ansible group names and vm_index must be 0 or greater (0 to disable)."
  }
}

variable "ansible_ssh_private_key_path" {
  description = "SSH private key path Ansible should use to connect to the Terraform-created VMs. If this file and ssh_public_key_path do not exist, Terraform generates them."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "enable_ansible_group_vars_domains" {
  description = "When true, Terraform writes Cloudflare hostnames into Ansible group_vars/<service>/terraform_domains.yml files."
  type        = bool
  default     = true
}

variable "ansible_group_vars_path" {
  description = "Path to the Ansible group_vars directory."
  type        = string
  default     = "../../../../../ansible_service_config/group_vars"
}

variable "enable_cloudflare_dns" {
  description = "When true, Terraform creates Cloudflare DNS records for service subdomains."
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Optional Cloudflare API token. Prefer using the CLOUDFLARE_API_TOKEN environment variable."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain, for example the zone ID for seang.shop."
  type        = string
  default     = ""
}

variable "cloudflare_dns_records" {
  description = "Cloudflare DNS records keyed by service name. A/AAAA records can use vm_index or content. CNAME records must use content."
  type = map(object({
    hostname             = string
    type                 = optional(string, "A")
    vm_index             = optional(number)
    content              = optional(string)
    proxied              = optional(bool, false)
    ttl                  = optional(number, 1)
    comment              = optional(string)
    enabled              = optional(bool, true)
    create_ansible_group = optional(bool, true)
    ansible_group        = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for _, record in var.cloudflare_dns_records : trimspace(record.hostname) != ""])
    error_message = "Each Cloudflare DNS record hostname must be non-empty."
  }

  validation {
    condition     = alltrue([for _, record in var.cloudflare_dns_records : contains(["A", "AAAA", "CNAME"], upper(record.type))])
    error_message = "Cloudflare DNS record type must be A, AAAA, or CNAME."
  }

  validation {
    condition = alltrue([
      for _, record in var.cloudflare_dns_records :
      upper(record.type) == "CNAME"
      ? try(trimspace(record.content), "") != ""
      : (try(record.vm_index, null) != null || try(trimspace(record.content), "") != "")
    ])
    error_message = "A/AAAA records must set either vm_index or content. CNAME records must set content."
  }

  validation {
    condition = alltrue([
      for _, record in var.cloudflare_dns_records :
      upper(record.type) != "CNAME" || try(record.vm_index, null) == null
    ])
    error_message = "CNAME records must use content and should not set vm_index."
  }

  validation {
    condition     = alltrue([for _, record in var.cloudflare_dns_records : try(record.vm_index >= 0, true)])
    error_message = "vm_index must be 0 or greater (0 disables DNS/Ansible generation, 1+ maps to a VM)."
  }

  validation {
    condition     = alltrue([for _, record in var.cloudflare_dns_records : try(record.ttl == 1 || (record.ttl >= 60 && record.ttl <= 86400), false)])
    error_message = "Cloudflare DNS record ttl must be 1 for automatic, or between 60 and 86400 seconds."
  }

  validation {
    condition = alltrue([
      for _, record in var.cloudflare_dns_records :
      try(record.ansible_group, null) == null || can(regex("^[A-Za-z0-9_-]+$", record.ansible_group))
    ])
    error_message = "ansible_group must be a valid Ansible inventory group name."
  }
}

# ---------------------------------------------------------------------------
# Multi-Cloud Activation Toggles
# ---------------------------------------------------------------------------
variable "enable_gcp" {
  description = "Enable GCP VM provisioning."
  type        = bool
  default     = true
}

variable "enable_aws" {
  description = "Enable AWS EC2 provisioning."
  type        = bool
  default     = false
}

variable "enable_digitalocean" {
  description = "Enable DigitalOcean Droplet provisioning."
  type        = bool
  default     = false
}

variable "gcp_instance_count" {
  description = "Number of GCP VMs to create. If null, falls back to instance_count."
  type        = number
  default     = null
}

variable "gcp_allocate_static_ips" {
  description = "Whether to reserve and assign static external IPs for GCP instances. When false, instances receive dynamic/ephemeral public IPs from GCP."
  type        = bool
  default     = true
}

variable "aws_instance_count" {
  description = "Number of AWS EC2 instances to create."
  type        = number
  default     = 0
}

variable "digitalocean_instance_count" {
  description = "Number of DigitalOcean Droplets to create."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------
# AWS Configuration
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS Region for EC2 instances."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "Optional AWS profile name."
  type        = string
  default     = ""
}

variable "aws_shared_credentials_file" {
  description = "Path to AWS shared credentials file (~/.aws/credentials)."
  type        = string
  default     = ""
}

variable "aws_shared_config_file" {
  description = "Path to AWS shared config file (~/.aws/config)."
  type        = string
  default     = ""
}

variable "aws_access_key" {
  description = "Optional AWS access key ID. Usually supplied via environment variable."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "Optional AWS secret access key. Usually supplied via environment variable."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_session_token" {
  description = "Optional AWS session token."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_availability_zones" {
  description = "List of AWS availability zones."
  type        = list(string)
  default     = []
}

variable "aws_auto_discover_up_zones" {
  description = "Whether to discover available AWS availability zones."
  type        = bool
  default     = true
}

variable "aws_blocked_availability_zones" {
  description = "List of AWS availability zones to skip."
  type        = list(string)
  default     = []
}

variable "aws_machine_types" {
  description = "List of AWS machine types (e.g. ['t4g.small'] or ['t3.medium'])."
  type        = list(string)
  default     = ["t4g.small"]
}

variable "aws_fallback_machine_types" {
  description = "List of fallback AWS machine types."
  type        = list(string)
  default     = ["t4g.small", "t3.medium", "t3a.medium"]
}

variable "aws_fallback_zones" {
  description = "Priority 2 AWS availability zones to use if preferred zones are unavailable or blocked."
  type        = list(string)
  default     = []
}

variable "aws_blocked_machine_types" {
  description = "List of EC2 instance types to skip/block (e.g. during stockout or quota limits)."
  type        = list(string)
  default     = []
}

variable "aws_random_resource_type" {
  description = "Resource family preferences ('Standard', 'High CPU', 'High Memory') for Priority 3 dynamic selection."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "aws_ami_id" {
  description = "Specific AMI ID. Leave empty for official Ubuntu 24.04 LTS."
  type        = string
  default     = ""
}

variable "aws_boot_disk_size_gb" {
  description = "AWS root volume size in GB."
  type        = number
  default     = 30
}

variable "aws_boot_disk_type" {
  description = "AWS root volume type (gp3)."
  type        = string
  default     = "gp3"
}

variable "aws_ssh_user" {
  description = "SSH user for connecting to AWS instances."
  type        = string
  default     = "ubuntu"
}

variable "aws_allocate_elastic_ips" {
  description = "Whether to assign static Elastic IPs to AWS instances."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# DigitalOcean Configuration
# ---------------------------------------------------------------------------
variable "do_token" {
  description = "DigitalOcean API token. Can also be supplied via DIGITALOCEAN_TOKEN env var."
  type        = string
  default     = ""
  sensitive   = true
}

variable "digitalocean_region" {
  description = "Primary DigitalOcean region slug (e.g. 'sgp1')."
  type        = string
  default     = "sgp1"
}

variable "digitalocean_regions" {
  description = "List of DigitalOcean regions."
  type        = list(string)
  default     = []
}

variable "digitalocean_auto_discover_up_regions" {
  description = "Whether to discover available DigitalOcean regions."
  type        = bool
  default     = true
}

variable "digitalocean_blocked_regions" {
  description = "List of DigitalOcean regions to skip."
  type        = list(string)
  default     = []
}

variable "digitalocean_sizes" {
  description = "Droplet sizes (e.g. ['s-2vcpu-4gb'])."
  type        = list(string)
  default     = ["s-2vcpu-4gb"]
}

variable "digitalocean_fallback_sizes" {
  description = "Fallback Droplet sizes."
  type        = list(string)
  default     = ["s-2vcpu-2gb", "s-4vcpu-8gb"]
}

variable "digitalocean_fallback_regions" {
  description = "Priority 2 fallback DigitalOcean regions to use if primary region is unavailable or blocked."
  type        = list(string)
  default     = []
}

variable "digitalocean_blocked_sizes" {
  description = "List of Droplet sizes to skip/block."
  type        = list(string)
  default     = []
}

variable "digitalocean_random_resource_type" {
  description = "Resource family preferences ('Standard', 'High CPU', 'High Memory') for Priority 3 dynamic selection."
  type        = list(string)
  default     = ["Standard", "High CPU", "High Memory"]
}

variable "digitalocean_image" {
  description = "DigitalOcean image slug."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "digitalocean_ssh_user" {
  description = "SSH user for connecting to DigitalOcean Droplets."
  type        = string
  default     = "root"
}

variable "digitalocean_allocate_reserved_ips" {
  description = "Whether to assign static Reserved IPs."
  type        = bool
  default     = true
}

