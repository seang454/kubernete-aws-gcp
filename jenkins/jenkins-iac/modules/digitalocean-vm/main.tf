# ---------------------------------------------------------------------------
# DigitalOcean VM Module for Jenkins & CI/CD Service Platform
# ---------------------------------------------------------------------------

data "digitalocean_regions" "available" {
  count = var.enabled && var.instance_count > 0 && var.auto_discover_up_regions ? 1 : 0
  filter {
    key    = "available"
    values = ["true"]
  }
}

locals {
  configured_regions = length(var.regions) > 0 ? var.regions : [var.region]

  discovered_up_regions = var.enabled && var.instance_count > 0 && var.auto_discover_up_regions ? [
    for r in try(data.digitalocean_regions.available[0].regions, []) : r.slug
    if r.available == true
  ] : local.configured_regions

  # Priority 1: User preferred regions in order, confirmed available and not blocked
  preferred_up_regions = var.auto_discover_up_regions ? [
    for r in local.configured_regions : r
    if contains(local.discovered_up_regions, r)
    && !contains(var.blocked_regions, r)
  ] : [
    for r in local.configured_regions : r
    if !contains(var.blocked_regions, r)
  ]

  # Priority 2: User fallback regions in order, confirmed available and not blocked
  fallback_up_regions = var.auto_discover_up_regions ? [
    for r in var.fallback_regions : r
    if contains(local.discovered_up_regions, r)
    && !contains(local.preferred_up_regions, r)
    && !contains(var.blocked_regions, r)
  ] : []

  # Priority 3: Dynamic remaining UP regions from DigitalOcean datacenters
  dynamic_remaining_up_regions = var.auto_discover_up_regions ? [
    for r in local.discovered_up_regions : r
    if !contains(local.preferred_up_regions, r)
    && !contains(local.fallback_up_regions, r)
    && !contains(var.blocked_regions, r)
  ] : []

  candidate_regions = concat(
    local.preferred_up_regions,
    local.fallback_up_regions,
    local.dynamic_remaining_up_regions
  )

  usable_regions = local.candidate_regions

  effective_regions = length(local.usable_regions) > 0 ? local.usable_regions : ["sgp1"]

  # Droplet Size Fallback Handling (Priority 1, 2, 3)
  fallback_size_candidates = distinct(compact(concat(
    var.fallback_sizes,
    contains(var.random_resource_type, "Standard") ? ["s-2vcpu-4gb", "s-4vcpu-8gb", "s-2vcpu-2gb"] : [],
    contains(var.random_resource_type, "High CPU") ? ["c-2", "c2-2vcpu-4gb"] : [],
    contains(var.random_resource_type, "High Memory") ? ["m-2vcpu-16gb"] : []
  )))

  usable_fallback_sizes = [
    for s in local.fallback_size_candidates : s
    if !contains(var.blocked_sizes, s)
  ]

  default_fallback_size = length(local.usable_fallback_sizes) > 0 ? local.usable_fallback_sizes[0] : "s-2vcpu-4gb"

  ssh_public_key = trimspace(var.ssh_public_key) != "" ? trimspace(var.ssh_public_key) : trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# SSH Key
resource "digitalocean_ssh_key" "this" {
  count      = var.enabled && var.instance_count > 0 && local.ssh_public_key != "" ? 1 : 0
  name       = "${var.name}-ssh-key"
  public_key = local.ssh_public_key
}

# Machine plan
locals {
  machines = [
    for index in range(var.instance_count) : {
      index        = index
      global_index = index + 1 + var.index_offset
      name         = format("%s-%d", var.name, index + 1 + var.index_offset)
      region       = local.effective_regions[index % length(local.effective_regions)]
      size = contains(var.blocked_sizes, var.sizes[min(index, length(var.sizes) - 1)]) ? (
        length(local.usable_fallback_sizes) > 0 ? local.usable_fallback_sizes[index % length(local.usable_fallback_sizes)] : local.default_fallback_size
      ) : var.sizes[min(index, length(var.sizes) - 1)]
    }
  ]
}

# Droplets
resource "digitalocean_droplet" "this" {
  count = var.enabled ? var.instance_count : 0

  name     = local.machines[count.index].name
  region   = local.machines[count.index].region
  size     = local.machines[count.index].size
  image    = var.image
  ssh_keys = length(digitalocean_ssh_key.this) > 0 ? [digitalocean_ssh_key.this[0].id] : []
  tags     = var.tags
}

# Reserved IPs
resource "digitalocean_reserved_ip" "this" {
  count  = var.enabled && var.allocate_reserved_ips ? var.instance_count : 0
  region = local.machines[count.index].region
}

resource "digitalocean_reserved_ip_assignment" "this" {
  count      = var.enabled && var.allocate_reserved_ips ? var.instance_count : 0
  ip_address = digitalocean_reserved_ip.this[count.index].ip_address
  droplet_id = digitalocean_droplet.this[count.index].id

  depends_on = [digitalocean_droplet.this, digitalocean_reserved_ip.this]
}

# Cloud Firewall
resource "digitalocean_firewall" "this" {
  count = var.enabled && var.instance_count > 0 ? 1 : 0
  name  = "${var.name}-firewall"

  droplet_ids = [for d in digitalocean_droplet.this : d.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_source_ranges
  }

  # Public web
  dynamic "inbound_rule" {
    for_each = var.public_service_ports
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.public_service_source_ranges
    }
  }

  # Additional ports
  dynamic "inbound_rule" {
    for_each = var.additional_service_ports
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.additional_service_source_ranges
    }
  }

  # Egress
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
