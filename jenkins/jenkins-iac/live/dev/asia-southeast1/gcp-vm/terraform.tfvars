# ---------------------------------------------------------------------------
# Cloud Provider Activation Toggles
# ---------------------------------------------------------------------------
enable_gcp          = true
enable_aws          = true
enable_digitalocean = false

# Distribution across clouds:
# VM 1 -> GCP (gcp-vm-1): 2 vCPUs (stays within GCP Free Trial 12 vCPU limit)
# VM 2 -> AWS (aws-vm-2): SonarQube, Nexus, DefectDojo
# VM 3 -> AWS (aws-vm-3): Harbor, Vault, Trivy
gcp_instance_count          = 1
aws_instance_count          = 2
digitalocean_instance_count = 0

# Fallback instance_count
instance_count = 1

# ---------------------------------------------------------------------------
# AWS Region & AZ Priority Architecture
# ---------------------------------------------------------------------------
aws_region = "ap-south-1"

# Priority 1: Preferred Availability Zones (in order, must be available)
aws_availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

aws_auto_discover_up_zones = true

# Priority 2: Fallback Availability Zones if preferred zones are unavailable
aws_fallback_zones = [
  "ap-south-1c"
]

# Priority 3: Dynamic remaining UP availability zones discovered via AWS API

# Outage blacklist filters (add any failing AZ or instance type to auto-failover):
aws_blocked_availability_zones = []
aws_blocked_machine_types      = []

# AWS Machine Types: Priority 1 primary, Priority 2 fallback
aws_machine_types          = ["t3.small"]
aws_fallback_machine_types = ["t3.small", "t3.micro"]
aws_random_resource_type   = ["Standard", "High CPU", "High Memory"]

aws_boot_disk_size_gb    = 40
aws_boot_disk_type       = "gp3"
aws_ssh_user             = "ubuntu"
aws_allocate_elastic_ips = true

# ---------------------------------------------------------------------------
# GCP Region & Zone Priority Architecture
# ---------------------------------------------------------------------------
project_id = "project-469c6b81-55a1-4508-830"
region     = "asia-southeast1"
zone       = "asia-southeast1-a"

# Priority 1: Preferred zones in order (spreads VMs across available zones)
zones = [
  "asia-southeast1-a",
  "asia-southeast1-b",
  "asia-southeast1-c"
]

auto_discover_up_zones = true

# Priority 2: Fallback regions if preferred zones are unavailable or exhausted
fallback_regions = [
  "asia-east1",
  "asia-northeast1"
]

# Priority 3: Dynamic nearest UP regions (auto-discovered from same continent first)

# Outage blacklist filters (add any failing zone or region to auto-failover):
blocked_zones         = []
blocked_regions       = []
blocked_machine_types = []

# GCP Machine Types: Priority 1 primary, Priority 2 fallback
machine_types          = ["n2d-standard-2"]
fallback_machine_types = ["n2d-standard-2", "e2-highcpu-2", "e2-highmem-2", "n4-standard-2"]
random_resource_type   = ["Standard", "High CPU", "High Memory"]
gcp_allocate_static_ips = true

# ---------------------------------------------------------------------------
# DigitalOcean Region & Size Priority Architecture
# ---------------------------------------------------------------------------
do_token            = ""
digitalocean_region = "sgp1"

# Priority 1: Preferred Datacenter regions
digitalocean_regions = [
  "sgp1"
]

digitalocean_auto_discover_up_regions = true

# Priority 2: Fallback regions if preferred region is down
digitalocean_fallback_regions = [
  "blr1",
  "syd1"
]

# Priority 3: Dynamic remaining UP regions from DigitalOcean API

digitalocean_blocked_regions = []
digitalocean_blocked_sizes   = []

digitalocean_sizes            = ["s-2vcpu-4gb"]
digitalocean_fallback_sizes   = ["s-2vcpu-2gb", "s-4vcpu-8gb"]
digitalocean_random_resource_type = ["Standard", "High CPU", "High Memory"]
digitalocean_image            = "ubuntu-24-04-x64"
digitalocean_ssh_user         = "root"
digitalocean_allocate_reserved_ips = true

# RUNNING keeps Terraform-managed VMs up. TERMINATED stops them.
desired_status = "RUNNING"

network    = "default"
subnetwork = null

ssh_user            = "seang"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Terraform writes the VM external IPs into this Ansible inventory after apply.
ansible_inventory_path       = "../../../../../jenkins-cac/inventories/dev/hosts.ini"
ansible_inventory_groups     = ["defectdojo", "harbor", "jenkins", "nexus", "sonarqube", "trivy", "vault"]
ansible_ssh_private_key_path = "~/.ssh/id_rsa"

# Explicit service-to-VM map. This keeps inventory correct even while
# Cloudflare DNS is disabled.
ansible_service_targets = {
  defectdojo = { vm_index = 2 }
  harbor     = { vm_index = 3 }
  jenkins    = { vm_index = 1 }
  nexus      = { vm_index = 2 }
  sonarqube  = { vm_index = 2 }
  trivy      = { vm_index = 3 }
  vault      = { vm_index = 3 }
}

enable_ansible_group_vars_domains = true
ansible_group_vars_path           = "../../../../../jenkins-cac/group_vars"

# Cloudflare DNS is disabled until you set your real zone ID and token.
# Prefer setting CLOUDFLARE_API_TOKEN in your shell instead of putting a token here.
enable_cloudflare_dns = true
cloudflare_zone_id    = "25794f1056c9f59652052d977bd73acb"
cloudflare_api_token  = ""

# vm_index is one-based:
# vm_index = 1 uses gcp-vm-1 external IP.
# vm_index = 2 uses gcp-vm-2 external IP.
# If you enable Cloudflare DNS with vm_index = 2, set instance_count = 2.
cloudflare_dns_records = {
  defectdojo = {
    hostname = "defectdojo-pro.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
    enabled  = true
  }

  harbor = {
    hostname = "harbor-pro.seang.shop"
    type     = "A"
    vm_index = 3
    proxied  = false
    enabled  = true
  }

  jenkins = {
    hostname = "jenkins-pro.seang.shop"
    type     = "A"
    vm_index = 1
    proxied  = false
    enabled  = true
  }

  sonarqube = {
    hostname = "sonarqube-pro.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
    enabled  = true
  }

  nexus = {
    hostname = "nexus-pro.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
    enabled  = true
  }

  nexus_docker = {
    hostname             = "docker-pro.seang.shop"
    type                 = "A"
    vm_index             = 2
    proxied              = false
    create_ansible_group = false
    enabled              = true
  }

  vault = {
    hostname = "vault-pro.seang.shop"
    type     = "A"
    vm_index = 3
    proxied  = false
    enabled  = true
  }

  trivy = {
    hostname = "trivy-pro.seang.shop"
    type     = "A"
    vm_index = 3
    proxied  = false
    enabled  = true
  }

  defectdojo_alias = {
    hostname = "dojo.seang.shop"
    type     = "CNAME"
    content  = "defectdojo-pro.seang.shop"
    proxied  = false
    enabled  = false
  }

  jenkins_alias = {
    hostname = "ci.seang.shop"
    type     = "CNAME"
    content  = "jenkins-pro.seang.shop"
    proxied  = false
    enabled  = false
  }

  nexus_alias = {
    hostname = "repo.seang.shop"
    type     = "CNAME"
    content  = "nexus-pro.seang.shop"
    proxied  = false
    enabled  = false
  }

  nexus_docker_alias = {
    hostname = "registry.seang.shop"
    type     = "CNAME"
    content  = "docker-pro.seang.shop"
    proxied  = false
    enabled  = false
  }

  sonarqube_alias = {
    hostname = "quality.seang.shop"
    type     = "CNAME"
    content  = "sonarqube-pro.seang.shop"
    proxied  = false
    enabled  = false
  }

  trivy_alias = {
    hostname = "scanner.seang.shop"
    type     = "CNAME"
    content  = "trivy-pro.seang.shop"
    proxied  = false
    enabled  = false
  }

  vault_alias = {
    hostname = "secrets.seang.shop"
    type     = "CNAME"
    content  = "vault-pro.seang.shop"
    proxied  = false
    enabled  = false
  }
}

# GCP firewall ports used by the Ansible service roles:
# - 22: SSH for Ansible. Restrict this to your public IP for real use.
# - 80: Nginx HTTP and Certbot validation.
# - 443: Nginx HTTPS for every service domain.
#
# Backend ports such as SonarQube 9000, Jenkins 8080, Nexus 8081/8082,
# Trivy 4954, and Vault 8200 stay behind Nginx and are not opened by GCP.
ssh_source_ranges            = ["0.0.0.0/0"]
public_service_ports         = [80, 443]
public_service_source_ranges = ["0.0.0.0/0"]

# Service backend ports (typically behind Nginx, but now exposed for direct access if needed):
# - Jenkins: 8080
# - SonarQube: 9000
# - Nexus UI: 8081
# - Nexus Docker repo: 8082
# - DefectDojo: 8000
# - Trivy: 4954
# - Vault: 8200
additional_service_ports         = [8000, 8080, 8081, 8082, 8200, 4954, 9000]
additional_service_source_ranges = ["0.0.0.0/0"]
