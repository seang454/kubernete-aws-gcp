# ---------------------------------------------------------------------------
# DigitalOcean Kubespray Nodes Module
# Implements full architectural parity with GCP and AWS modules:
#  1. Dynamic Region/Datacenter Discovery & Health Checking (available = true)
#  2. Droplet Size Stockout & Fallback Handling (blocked_sizes)
#  3. Preflight Safety Preconditions (terraform_data.preflight)
#  4. Static Reserved IP Reservation (preserved across stop/start)
#  5. Storage Architecture (Boot + Optional Secondary Block Storage Volume)
#  6. Power State Control (RUNNING vs TERMINATED via DigitalOcean API)
#  7. Selective Node Deletion (exclude_nodes) & Selective Node Stop (stop_nodes)
#  8. Multi-Cloud & Cross-VPC Firewall / Ingress Rules (digitalocean_firewall)
# ---------------------------------------------------------------------------

# 1. Dynamic Region Discovery & Region Health (Concept 1)
data "digitalocean_regions" "available" {
  count = var.enabled && (var.worker_count + var.control_plane_count) > 0 && var.auto_discover_up_regions ? 1 : 0
  filter {
    key    = "available"
    values = ["true"]
  }
}

locals {
  configured_regions = length(var.regions) > 0 ? var.regions : [var.region]

  discovered_up_regions = var.enabled && (var.worker_count + var.control_plane_count) > 0 && var.auto_discover_up_regions ? [
    for r in try(data.digitalocean_regions.available[0].regions, []) : r.slug
    if r.available == true
  ] : local.configured_regions

  # Preferred configured regions that are confirmed available/UP
  preferred_up_regions = length(local.configured_regions) > 0 ? [
    for r in local.configured_regions : r
    if contains(local.discovered_up_regions, r)
  ] : local.discovered_up_regions

  # Fallback regions from available regions not explicitly in preferred
  fallback_up_regions = [
    for r in local.discovered_up_regions : r
    if !contains(local.preferred_up_regions, r)
  ]

  candidate_regions = concat(local.preferred_up_regions, local.fallback_up_regions)

  # Filter out blocked regions
  usable_regions = [
    for r in local.candidate_regions : r
    if !contains(var.blocked_regions, r)
  ]

  effective_regions = length(local.usable_regions) > 0 ? local.usable_regions : [var.region]
}

# 2. Droplet Size Stockout & Fallback Handling (Concept 2)
locals {
  fallback_machine_candidates = distinct(compact(concat(
    var.fallback_sizes,
    contains(var.random_resource_type, "Standard") ? ["s-2vcpu-4gb", "s-4vcpu-8gb", "s-2vcpu-2gb"] : [],
    contains(var.random_resource_type, "High CPU") ? ["c-2", "c2-2vcpu-4gb"] : [],
    contains(var.random_resource_type, "High Memory") ? ["m-2vcpu-16gb"] : []
  )))

  usable_fallback_machines = [
    for m in local.fallback_machine_candidates : m
    if !contains(var.blocked_sizes, m)
  ]

  default_fallback_machine = length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[0] : "s-2vcpu-4gb"
}

# 3. SSH Key Pair
resource "digitalocean_ssh_key" "this" {
  count      = var.enabled && (var.worker_count + var.control_plane_count) > 0 ? 1 : 0
  name       = "${var.instance_name_prefix}-key-${substr(md5(trimspace(var.ssh_public_key)), 0, 8)}"
  public_key = trimspace(var.ssh_public_key)
}

# 4. Node Planning & Selective Deletion (Concept 7)
locals {
  control_plane_nodes = var.enabled ? [
    for index in range(var.control_plane_count) : {
      name          = format("%s%02d", var.control_plane_name_prefix, index + 1 + var.control_plane_index_offset)
      instance_name = format("%s-%s%02d", var.instance_name_prefix, var.control_plane_name_prefix, index + 1 + var.control_plane_index_offset)
      role          = "control_plane"
      cloud         = "digitalocean"
      node_index    = index
      global_index  = index + var.control_plane_index_offset
      zone          = try(local.effective_regions[index % length(local.effective_regions)], var.region)
      machine_type = contains(var.blocked_sizes, var.control_plane_sizes[min(index, length(var.control_plane_sizes) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[(index + var.control_plane_index_offset) % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.control_plane_sizes[min(index, length(var.control_plane_sizes) - 1)]
      has_secondary_disk = var.control_plane_data_disk_size_gb > 0
    }
  ] : []

  worker_nodes = var.enabled ? [
    for index in range(var.worker_count) : {
      name          = format("%s%02d", var.worker_name_prefix, index + 1 + var.index_offset)
      instance_name = format("%s-%s%02d", var.instance_name_prefix, var.worker_name_prefix, index + 1 + var.index_offset)
      role          = "worker"
      cloud         = "digitalocean"
      node_index    = index
      global_index  = index + var.index_offset
      zone          = try(local.effective_regions[index % length(local.effective_regions)], var.region)
      machine_type = contains(var.blocked_sizes, var.worker_sizes[min(index, length(var.worker_sizes) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[(index + var.index_offset) % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.worker_sizes[min(index, length(var.worker_sizes) - 1)]
      has_secondary_disk = var.worker_data_disk_size_gb > 0
    }
  ] : []

  all_nodes         = concat(local.control_plane_nodes, local.worker_nodes)
  all_nodes_by_name = { for node in local.all_nodes : node.name => node }

  active_control_plane_nodes = var.enabled ? [
    for node in local.control_plane_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ] : []

  active_worker_nodes = var.enabled ? [
    for node in local.worker_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ] : []

  active_nodes         = concat(local.active_control_plane_nodes, local.active_worker_nodes)
  active_nodes_by_name = { for node in local.active_nodes : node.name => node }
}

# 5. Preflight Safety Preconditions (Concept 3)
resource "terraform_data" "preflight" {
  count = var.enabled && (var.worker_count + var.control_plane_count) > 0 ? 1 : 0

  input = {
    total_node_count         = var.worker_count + var.control_plane_count
    configured_regions       = local.configured_regions
    usable_regions           = local.usable_regions
    blocked_regions          = var.blocked_regions
    blocked_sizes            = var.blocked_sizes
    usable_fallback_machines = local.usable_fallback_machines
    exclude_nodes            = var.exclude_nodes
    stop_nodes               = var.stop_nodes
  }

  lifecycle {
    precondition {
      condition     = (var.worker_count + var.control_plane_count) == 0 || length(local.usable_regions) > 0
      error_message = "No usable DigitalOcean regions remain. Remove entries from blocked_regions or configure more regions."
    }

    precondition {
      condition     = length(local.usable_fallback_machines) > 0 || length(var.blocked_sizes) == 0
      error_message = "All fallback DigitalOcean droplet sizes are blocked. Remove entries from blocked_sizes or add candidates to fallback_sizes."
    }

    precondition {
      condition     = alltrue([for name in var.exclude_nodes : contains([for n in local.all_nodes : n.instance_name], name)])
      error_message = "exclude_nodes contains invalid DigitalOcean instance name(s). Valid names are: ${join(", ", [for n in local.all_nodes : n.instance_name])}"
    }

    precondition {
      condition     = alltrue([for name in var.stop_nodes : contains([for n in local.all_nodes : n.instance_name], name)])
      error_message = "stop_nodes contains invalid DigitalOcean instance name(s). Valid names are: ${join(", ", [for n in local.all_nodes : n.instance_name])}"
    }

    precondition {
      condition     = length(setintersection(toset(var.exclude_nodes), toset(var.stop_nodes))) == 0
      error_message = "A node cannot be in both exclude_nodes (delete) and stop_nodes (stop): ${join(", ", setintersection(toset(var.exclude_nodes), toset(var.stop_nodes)))}"
    }
  }
}

# 6. DigitalOcean Droplets
resource "digitalocean_droplet" "this" {
  for_each = local.active_nodes_by_name

  name     = each.value.instance_name
  region   = each.value.zone
  size     = each.value.machine_type
  image    = var.image
  ssh_keys = length(digitalocean_ssh_key.this) > 0 ? [digitalocean_ssh_key.this[0].id] : []
  vpc_uuid = var.vpc_uuid

  user_data = templatefile("${path.module}/templates/user_data.tftpl", {
    ssh_user       = var.ssh_user
    ssh_public_key = var.ssh_public_key
  })

  tags = concat(var.tags, [
    var.cluster_name,
    each.value.role,
    "k8s",
    "digitalocean"
  ])

  lifecycle {
    ignore_changes = [
      image
    ]
  }

  depends_on = [terraform_data.preflight]
}

# 7. Secondary Block Storage Volume (Concept 5: Storage Architecture)
resource "digitalocean_volume" "data" {
  for_each = {
    for name, node in local.active_nodes_by_name :
    name => node
    if node.has_secondary_disk
  }

  region                  = each.value.zone
  name                    = "${each.value.instance_name}-data"
  size                    = each.value.role == "control_plane" ? var.control_plane_data_disk_size_gb : var.worker_data_disk_size_gb
  initial_filesystem_type = var.worker_data_disk_filesystem
  description             = "Secondary block storage for ${each.value.instance_name}"
}

resource "digitalocean_volume_attachment" "data" {
  for_each = {
    for name, node in local.active_nodes_by_name :
    name => node
    if node.has_secondary_disk
  }

  droplet_id = digitalocean_droplet.this[each.key].id
  volume_id  = digitalocean_volume.data[each.key].id
}

# 8. Static Reserved IPs (Concept 4: Preserving IP across stop/start)
resource "digitalocean_reserved_ip" "this" {
  for_each = var.allocate_reserved_ips ? local.active_nodes_by_name : {}
  region   = each.value.zone
}

resource "digitalocean_reserved_ip_assignment" "this" {
  for_each   = var.allocate_reserved_ips ? local.active_nodes_by_name : {}
  ip_address = digitalocean_reserved_ip.this[each.key].ip_address
  droplet_id = digitalocean_droplet.this[each.key].id
}

# 9. Custom Firewall Rule Resolution (Concept 8)
locals {
  active_custom_rules = flatten([
    for rule in var.custom_firewall_rules : [
      for port in rule.ports : {
        name          = rule.name
        protocol      = lower(rule.protocol) == "all" ? "tcp" : lower(rule.protocol)
        port_range    = port
        source_ranges = rule.source_ranges
      }
    ]
    if(
      coalesce(rule.target, "all") == "all" ||
      (coalesce(rule.target, "all") == "worker" && var.worker_count > 0) ||
      (coalesce(rule.target, "all") == "control_plane" && var.control_plane_count > 0)
    )
  ])
}

# 10. DigitalOcean Cloud Firewall
resource "digitalocean_firewall" "k8s" {
  count = length(local.active_nodes) > 0 ? 1 : 0
  name  = "${var.instance_name_prefix}-firewall"

  droplet_ids = [for d in digitalocean_droplet.this : d.id]

  # SSH (port 22)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_source_ranges
  }

  # WireGuard VPN Mesh (udp 51820)
  dynamic "inbound_rule" {
    for_each = length(var.wireguard_source_ranges) > 0 ? [1] : []
    content {
      protocol         = "udp"
      port_range       = "51820"
      source_addresses = var.wireguard_source_ranges
    }
  }

  # Kubernetes API (tcp 6443) for control plane nodes
  dynamic "inbound_rule" {
    for_each = var.control_plane_count > 0 && length(var.kubernetes_api_source_ranges) > 0 ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "6443"
      source_addresses = var.kubernetes_api_source_ranges
    }
  }

  # etcd (tcp 2379-2380) for control plane nodes
  dynamic "inbound_rule" {
    for_each = var.control_plane_count > 0 && length(var.cluster_source_ranges) > 0 ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "2379-2380"
      source_addresses = var.cluster_source_ranges
    }
  }

  # Kubelet API (tcp 10250)
  dynamic "inbound_rule" {
    for_each = length(var.kubelet_source_ranges) > 0 ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "10250"
      source_addresses = var.kubelet_source_ranges
    }
  }

  # Kubernetes NodePort range (30000-32767)
  dynamic "inbound_rule" {
    for_each = length(var.nodeport_source_ranges) > 0 ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "30000-32767"
      source_addresses = var.nodeport_source_ranges
    }
  }

  # Inter-node / Cross-cloud communication (GCP, AWS, and DigitalOcean public IPs)
  dynamic "inbound_rule" {
    for_each = length(var.cluster_source_ranges) > 0 && var.enable_cross_cluster_rule ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "1-65535"
      source_addresses = var.cluster_source_ranges
    }
  }

  dynamic "inbound_rule" {
    for_each = length(var.cluster_source_ranges) > 0 && var.enable_cross_cluster_rule ? [1] : []
    content {
      protocol         = "udp"
      port_range       = "1-65535"
      source_addresses = var.cluster_source_ranges
    }
  }

  dynamic "inbound_rule" {
    for_each = length(var.cluster_source_ranges) > 0 && var.enable_cross_cluster_rule ? [1] : []
    content {
      protocol         = "icmp"
      source_addresses = var.cluster_source_ranges
    }
  }

  # Custom firewall rules
  dynamic "inbound_rule" {
    for_each = local.active_custom_rules
    content {
      protocol         = inbound_rule.value.protocol
      port_range       = inbound_rule.value.port_range
      source_addresses = inbound_rule.value.source_ranges
    }
  }

  # Outbound egress (Allow all outbound traffic)
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

# 11. Power State Management (Concept 6: RUNNING vs TERMINATED)
resource "terraform_data" "droplet_power" {
  for_each = local.active_nodes_by_name

  input = {
    droplet_id     = digitalocean_droplet.this[each.key].id
    desired_action = contains(var.stop_nodes, each.value.instance_name) || var.desired_status == "TERMINATED" ? "power_off" : "power_on"
    do_token       = var.do_token
  }

  triggers_replace = [
    contains(var.stop_nodes, each.value.instance_name) || var.desired_status == "TERMINATED" ? "power_off" : "power_on"
  ]

  provisioner "local-exec" {
    command = <<-EOT
      TOKEN="${self.input.do_token}"
      [ -z "$TOKEN" ] && TOKEN="$DIGITALOCEAN_TOKEN"
      [ -z "$TOKEN" ] && TOKEN="$DIGITALOCEAN_ACCESS_TOKEN"

      if [ -n "$TOKEN" ]; then
        ACTION="${self.input.desired_action}"
        DROPLET_ID="${self.input.droplet_id}"
        echo "DigitalOcean Droplet $DROPLET_ID: Executing $ACTION..."
        curl -s -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"type\":\"$ACTION\"}" \
          "https://api.digitalocean.com/v2/droplets/$DROPLET_ID/actions" >/dev/null || true
      fi
    EOT
  }

  depends_on = [digitalocean_droplet.this]
}
