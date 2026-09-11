locals {
  cluster_tag       = "${var.instance_name_prefix}-cluster"
  control_plane_tag = "${var.instance_name_prefix}-control-plane"
  worker_tag        = "${var.instance_name_prefix}-worker"

  configured_zones   = length(var.zones) > 0 ? var.zones : [var.zone]
  configured_regions = distinct([for zone in local.configured_zones : replace(zone, "/-[a-z]$/", "")])
  discovery_regions  = distinct(concat(local.configured_regions, var.fallback_regions))
}

data "google_compute_zones" "available" {
  for_each = var.auto_discover_up_zones ? toset(local.discovery_regions) : toset([])

  region = each.value
  status = "UP"
}

locals {
  discovered_up_zones = flatten([
    for region in local.discovery_regions : try(data.google_compute_zones.available[region].names, [])
  ])

  preferred_up_zones = var.auto_discover_up_zones ? [
    for zone in local.configured_zones : zone
    if contains(local.discovered_up_zones, zone)
  ] : local.configured_zones

  fallback_up_zones = var.auto_discover_up_zones ? [
    for zone in local.discovered_up_zones : zone
    if !contains(local.configured_zones, zone)
  ] : []

  candidate_zones = concat(local.preferred_up_zones, local.fallback_up_zones)

  usable_zones = [
    for zone in local.candidate_zones : zone
    if !contains(var.blocked_zones, zone) && !contains(var.blocked_regions, replace(zone, "/-[a-z]$/", ""))
  ]

  effective_zones = length(local.usable_zones) > 0 ? local.usable_zones : ["no-usable-zone"]

  fallback_machine_candidates = distinct(compact(concat(
    var.fallback_machine_types,
    contains(var.random_resource_type, "Standard") ? ["n1-standard-1", "e2-medium", "e2-small", "g1-small"] : [],
    contains(var.random_resource_type, "High CPU") ? ["e2-highcpu-2"] : [],
    contains(var.random_resource_type, "High Memory") ? ["e2-highmem-2"] : []
  )))

  usable_fallback_machines = [
    for m in local.fallback_machine_candidates : m
    if !contains(var.blocked_machine_types, m)
  ]

  default_fallback_machine = length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[0] : "n1-standard-1"

  control_plane_nodes = [
    for index in range(var.control_plane_count) : {
      name              = format("%s%02d", var.control_plane_name_prefix, index + 1)
      instance_name     = format("%s-%s%02d", var.instance_name_prefix, var.control_plane_name_prefix, index + 1)
      role              = "control_plane"
      node_index        = index
      global_index      = index
      zone              = local.effective_zones[index % length(local.effective_zones)]
      region            = replace(local.effective_zones[index % length(local.effective_zones)], "/-[a-z]$/", "")
      machine_type      = contains(var.blocked_machine_types, var.control_plane_machine_types[min(index, length(var.control_plane_machine_types) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[index % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.control_plane_machine_types[min(index, length(var.control_plane_machine_types) - 1)]
      boot_disk_size_gb = var.control_plane_boot_disk_size_gb
      has_secondary_disk= false
    }
  ]

  worker_nodes = [
    for index in range(var.worker_count) : {
      name              = format("%s%02d", var.worker_name_prefix, index + 1)
      instance_name     = format("%s-%s%02d", var.instance_name_prefix, var.worker_name_prefix, index + 1)
      role              = "worker"
      node_index        = index
      global_index      = var.control_plane_count + index
      zone              = local.effective_zones[(var.control_plane_count + index) % length(local.effective_zones)]
      region            = replace(local.effective_zones[(var.control_plane_count + index) % length(local.effective_zones)], "/-[a-z]$/", "")
      machine_type      = contains(var.blocked_machine_types, var.worker_machine_types[min(index, length(var.worker_machine_types) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[(var.control_plane_count + index) % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.worker_machine_types[min(index, length(var.worker_machine_types) - 1)]
      boot_disk_size_gb = var.worker_boot_disk_size_gb
      has_secondary_disk= false
    }
  ]

  nfs_effective_zones = length(var.nfs_zones) > 0 ? var.nfs_zones : local.effective_zones

  nfs_nodes = [
    for index in range(var.nfs_count) : {
      name              = format("%s-%d", var.nfs_name_prefix, index + 1)
      instance_name     = format("%s-%s-%d", var.instance_name_prefix, var.nfs_name_prefix, index + 1)
      role              = "nfs"
      node_index        = index
      global_index      = var.control_plane_count + var.worker_count + index
      zone              = local.nfs_effective_zones[index % length(local.nfs_effective_zones)]
      region            = replace(local.nfs_effective_zones[index % length(local.nfs_effective_zones)], "/-[a-z]$/", "")
      machine_type      = contains(var.blocked_machine_types, var.nfs_machine_types[min(index, length(var.nfs_machine_types) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[(var.control_plane_count + var.worker_count + index) % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.nfs_machine_types[min(index, length(var.nfs_machine_types) - 1)]
      boot_disk_size_gb = var.nfs_boot_disk_size_gb
      has_secondary_disk= true
    }
  ]

  nodes         = concat(local.control_plane_nodes, local.worker_nodes, local.nfs_nodes)
  nodes_by_name = { for node in local.nodes : node.name => node }
  nfs_nodes_by_name = { for node in local.nfs_nodes : node.name => node }
  control_plane_nodes_by_name = { for node in local.control_plane_nodes : node.name => node }

  ssh_public_key = trimspace(var.ssh_public_key) != "" ? trimspace(var.ssh_public_key) : trimspace(file(pathexpand(var.ssh_public_key_path)))

  # -------------------------------------------------------------------------
  # Filtered node sets — exclude specific nodes by GCP instance name
  # -------------------------------------------------------------------------
  active_nodes = [
    for node in local.nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ]

  active_nodes_by_name = {
    for name, node in local.nodes_by_name :
    name => node
    if !contains(var.exclude_nodes, node.instance_name)
  }

  active_nfs_nodes_by_name = {
    for name, node in local.nfs_nodes_by_name :
    name => node
    if !contains(var.exclude_nodes, node.instance_name)
  }

  active_control_plane_nodes = [
    for node in local.control_plane_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ]

  active_worker_nodes = [
    for node in local.worker_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ]

  active_nfs_nodes = [
    for node in local.nfs_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ]
}

resource "terraform_data" "preflight" {
  input = {
    configured_zones      = local.configured_zones
    usable_zones          = local.usable_zones
    blocked_zones         = var.blocked_zones
    blocked_regions       = var.blocked_regions
    blocked_machine_types = var.blocked_machine_types
    usable_fallbacks      = local.usable_fallback_machines
  }

  lifecycle {
    precondition {
      condition     = length(local.usable_zones) > 0
      error_message = "No usable GCP zones remain. Remove values from blocked_zones/blocked_regions or add more zones."
    }

    precondition {
      condition     = length(local.usable_fallback_machines) > 0 || length(var.blocked_machine_types) == 0
      error_message = "All fallback machine types are blocked. Remove entries from blocked_machine_types or add candidates to fallback_machine_types."
    }

    precondition {
      condition     = alltrue([for name in var.exclude_nodes : contains([for n in local.nodes : n.instance_name], name)])
      error_message = "exclude_nodes contains invalid instance name(s). Valid names are: ${join(", ", [for n in local.nodes : n.instance_name])}"
    }
  }
}

# Create secondary data disk for Ceph OSD on NFS nodes (/dev/sdb)
resource "google_compute_disk" "ceph_osd" {
  for_each = local.active_nfs_nodes_by_name

  name = "${each.value.instance_name}-ceph-osd"
  type = var.boot_disk_type
  zone = each.value.zone
  size = var.nfs_data_disk_size_gb

  labels = merge(var.labels, {
    purpose = "ceph-osd"
  })

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_address" "this" {
  for_each = local.active_nodes_by_name

  name   = "${each.value.instance_name}-ip"
  region = each.value.region

  depends_on = [terraform_data.preflight]
}

resource "google_compute_instance" "this" {
  for_each = local.active_nodes_by_name

  name                      = each.value.instance_name
  machine_type              = each.value.machine_type
  desired_status            = var.desired_status
  allow_stopping_for_update = true
  zone                      = each.value.zone

  tags = distinct(concat(
    var.network_tags,
    [
      local.cluster_tag,
      each.value.role == "control_plane" ? local.control_plane_tag : (each.value.role == "worker" ? local.worker_tag : "${var.instance_name_prefix}-nfs"),
    ]
  ))

  boot_disk {
    initialize_params {
      image = var.image
      size  = each.value.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  dynamic "attached_disk" {
    for_each = each.value.has_secondary_disk ? [1] : []
    content {
      source      = google_compute_disk.ceph_osd[each.key].self_link
      device_name = "sdb"
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    access_config {
      nat_ip = google_compute_address.this[each.key].address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
  }

  labels = merge(var.labels, {
    cluster = var.cluster_name
    role    = each.value.role
  })
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.instance_name_prefix}-allow-ssh"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [local.cluster_tag]
}

resource "google_compute_firewall" "internal" {
  name    = "${var.instance_name_prefix}-allow-internal"
  network = var.network

  allow {
    protocol = "all"
  }

  source_ranges = var.internal_source_ranges
  target_tags   = [local.cluster_tag]
}

resource "google_compute_firewall" "kubernetes_api" {
  name    = "${var.instance_name_prefix}-allow-kube-api"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = var.kubernetes_api_source_ranges
  target_tags   = [local.control_plane_tag]
}

resource "google_compute_firewall" "nodeport" {
  count = length(var.nodeport_source_ranges) > 0 ? 1 : 0

  name    = "${var.instance_name_prefix}-allow-nodeport"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = var.nodeport_source_ranges
  target_tags   = [local.cluster_tag]
}

# ---------------------------------------------------------------------------
# Custom firewall rules (from var.custom_firewall_rules)
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "custom" {
  for_each = {
    for rule in var.custom_firewall_rules :
    rule.name => rule
  }

  name    = "${var.instance_name_prefix}-custom-${each.key}"
  network = var.network

  allow {
    protocol = each.value.protocol
    ports    = each.value.ports
  }

  source_ranges = each.value.source_ranges

  target_tags = (
    coalesce(each.value.target, "all") == "control_plane" ? [local.control_plane_tag] :
    coalesce(each.value.target, "all") == "worker" ? [local.worker_tag] :
    [local.cluster_tag]
  )
}
