locals {
  # Calculate instance names for GCP and AWS for preflight checks and clean exclude routing
  gcp_control_plane_names = [
    for i in range(var.control_plane_count) :
    format("%s-%s%02d", var.instance_name_prefix, var.control_plane_name_prefix, i + 1)
  ]
  gcp_worker_names = [
    for i in range(var.gcp_worker_count) :
    format("%s-%s%02d", var.instance_name_prefix, var.worker_name_prefix, i + 1)
  ]
  gcp_instance_names = concat(local.gcp_control_plane_names, local.gcp_worker_names)

  aws_worker_names = [
    for i in range(var.aws_worker_count) :
    format("%s-%s%02d", var.instance_name_prefix, var.worker_name_prefix, i + 1 + var.gcp_worker_count)
  ]

  all_instance_names = concat(local.gcp_instance_names, local.aws_worker_names)

  # Route exclude_nodes so submodules only receive names belonging to their cloud
  gcp_exclude_nodes = [for name in var.exclude_nodes : name if contains(local.gcp_instance_names, name)]
  aws_exclude_nodes = [for name in var.exclude_nodes : name if contains(local.aws_worker_names, name)]

  # Route stop_nodes so submodules only receive names belonging to their cloud
  gcp_stop_nodes = [for name in var.stop_nodes : name if contains(local.gcp_instance_names, name)]
  aws_stop_nodes = [for name in var.stop_nodes : name if contains(local.aws_worker_names, name)]
}

# Root preflight precondition: validate that all entries in exclude_nodes and stop_nodes exist
resource "terraform_data" "root_preflight" {
  input = {
    exclude_nodes      = var.exclude_nodes
    stop_nodes         = var.stop_nodes
    all_instance_names = local.all_instance_names
  }

  lifecycle {
    precondition {
      condition     = alltrue([for name in var.exclude_nodes : contains(local.all_instance_names, name)])
      error_message = "exclude_nodes contains invalid instance name(s). Valid names are: ${join(", ", local.all_instance_names)}"
    }

    precondition {
      condition     = alltrue([for name in var.stop_nodes : contains(local.all_instance_names, name)])
      error_message = "stop_nodes contains invalid instance name(s). Valid names are: ${join(", ", local.all_instance_names)}"
    }

    precondition {
      condition     = length(setintersection(toset(var.exclude_nodes), toset(var.stop_nodes))) == 0
      error_message = "A node cannot be in both exclude_nodes (delete) and stop_nodes (stop): ${join(", ", setintersection(toset(var.exclude_nodes), toset(var.stop_nodes)))}"
    }
  }
}

# ---------------------------------------------------------------------------
# GCP Cluster Module: 3 Control-plane nodes
# ---------------------------------------------------------------------------
module "gcp_kubespray_cluster" {
  source = "../../../../modules/gcp-kubespray-cluster"

  cluster_name                    = var.cluster_name
  instance_name_prefix            = var.instance_name_prefix
  control_plane_count             = var.control_plane_count
  worker_count                    = var.gcp_worker_count
  control_plane_name_prefix       = var.control_plane_name_prefix
  worker_name_prefix              = var.worker_name_prefix
  zone                            = var.zone
  zones                           = var.zones
  auto_discover_up_zones          = var.auto_discover_up_zones
  fallback_regions                = var.fallback_regions
  blocked_zones                   = var.blocked_zones
  blocked_regions                 = var.blocked_regions
  blocked_machine_types           = var.blocked_machine_types
  control_plane_machine_types     = var.control_plane_machine_types
  worker_machine_types            = var.worker_machine_types
  fallback_machine_types          = var.fallback_machine_types
  random_resource_type            = var.random_resource_type
  desired_status                  = var.desired_status
  image                           = var.image
  control_plane_boot_disk_size_gb = var.control_plane_boot_disk_size_gb
  worker_boot_disk_size_gb        = var.worker_boot_disk_size_gb
  boot_disk_type                  = var.boot_disk_type
  network                         = var.network
  subnetwork                      = var.subnetwork
  ssh_user                        = var.ssh_user
  ssh_public_key_path             = var.ssh_public_key_path
  ssh_public_key                  = local.ssh_public_key
  ssh_source_ranges               = var.ssh_source_ranges
  internal_source_ranges          = distinct(concat(var.internal_source_ranges, [var.aws_vpc_cidr]))
  kubernetes_api_source_ranges    = var.kubernetes_api_source_ranges
  nodeport_source_ranges          = var.nodeport_source_ranges
  network_tags                    = var.network_tags
  custom_firewall_rules           = var.custom_firewall_rules
  exclude_nodes                   = local.gcp_exclude_nodes
  stop_nodes                      = local.gcp_stop_nodes

  labels = {
    environment = "dev"
    app         = "kubespray"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# AWS Workers Module: 4 Worker nodes
# ---------------------------------------------------------------------------
module "aws_kubespray_workers" {
  source = "../../../../modules/aws-kubespray-workers"

  cluster_name                 = var.cluster_name
  instance_name_prefix         = var.instance_name_prefix
  worker_count                 = var.aws_worker_count
  worker_name_prefix           = var.worker_name_prefix
  index_offset                 = var.gcp_worker_count
  aws_region                   = var.aws_region
  zones                        = var.aws_availability_zones
  auto_discover_up_zones       = var.aws_auto_discover_up_zones
  blocked_zones                = var.aws_blocked_availability_zones
  vpc_id                       = var.aws_vpc_id
  subnet_ids                   = var.aws_subnet_ids
  worker_machine_types         = var.aws_worker_instance_types
  fallback_machine_types       = var.aws_fallback_machine_types
  blocked_machine_types        = var.aws_blocked_machine_types
  random_resource_type         = var.aws_random_resource_type
  ami_id                       = var.aws_worker_ami_id
  root_volume_size_gb          = var.aws_worker_root_disk_size_gb
  root_volume_type             = var.aws_worker_root_disk_type
  worker_data_disk_size_gb     = var.aws_worker_data_disk_size_gb
  worker_data_disk_type        = var.aws_worker_data_disk_type
  ssh_user                     = var.ssh_user
  ssh_public_key               = local.ssh_public_key
  ssh_source_ranges            = var.ssh_source_ranges
  cluster_source_ranges        = distinct(concat(var.internal_source_ranges, [for ip in module.gcp_kubespray_cluster.cluster_public_ips : "${ip}/32" if ip != null && ip != ""]))
  kubernetes_api_source_ranges = var.kubernetes_api_source_ranges
  nodeport_source_ranges       = var.nodeport_source_ranges
  custom_firewall_rules        = var.custom_firewall_rules
  desired_status               = var.desired_status
  allocate_elastic_ips         = var.aws_allocate_elastic_ips
  source_dest_check            = var.aws_source_dest_check
  exclude_nodes                = local.aws_exclude_nodes
  stop_nodes                   = local.aws_stop_nodes

  tags = {
    environment = "dev"
    app         = "kubespray"
    managed_by  = "terraform"
    cluster     = var.cluster_name
  }
}

# ---------------------------------------------------------------------------
# Cross-Cloud Firewall: Allow traffic from AWS worker nodes to GCP cluster
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_aws_workers" {
  count   = var.aws_worker_count > 0 && var.use_public_access_ip ? 1 : 0
  name    = "${var.instance_name_prefix}-allow-aws-workers"
  network = var.network

  allow {
    protocol = "all"
  }

  source_ranges = length(module.aws_kubespray_workers.worker_public_ips) > 0 ? [
    for ip in module.aws_kubespray_workers.worker_public_ips : "${ip}/32" if ip != null && ip != ""
  ] : [var.aws_vpc_cidr]

  target_tags = ["${var.cluster_name}-cluster"]
}
