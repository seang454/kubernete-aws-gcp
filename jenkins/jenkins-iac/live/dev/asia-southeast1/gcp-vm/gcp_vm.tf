/*
This live dev root module calls the reusable GCP VM module.

Flow:
live/dev/asia-southeast1/gcp-vm/gcp_vm.tf
  -> modules/gcp-vm
  -> creates GCP VM instances and firewall rules

gcp_vm.tf in live/dev
        |
        | calls
        v
modules/gcp-vm
        |
        | creates
        v
GCP VM instances + firewall rules

*/

module "gcp_vm" {
  source = "../../../../modules/gcp-vm"

  enabled        = var.enable_gcp
  name           = var.name
  instance_count = local.effective_gcp_instance_count
  zone                   = var.zone
  zones                  = var.zones
  auto_discover_up_zones = var.auto_discover_up_zones
  fallback_regions       = var.fallback_regions
  blocked_zones          = var.blocked_zones
  blocked_regions        = var.blocked_regions
  blocked_machine_types  = var.blocked_machine_types
  machine_types          = var.machine_types
  fallback_machine_types = var.fallback_machine_types
  random_resource_type   = var.random_resource_type
  desired_status         = var.desired_status
  image                  = var.image
  boot_disk_size_gb      = var.boot_disk_size_gb
  boot_disk_type         = var.boot_disk_type
  network                = var.network
  subnetwork             = var.subnetwork
  ssh_user               = var.ssh_user
  ssh_public_key_path    = var.ssh_public_key_path
  ssh_public_key         = local.ssh_public_key

  allocate_static_ips              = var.gcp_allocate_static_ips
  ssh_source_ranges                = var.ssh_source_ranges
  public_service_ports             = var.public_service_ports
  public_service_source_ranges     = var.public_service_source_ranges
  additional_service_ports         = var.additional_service_ports
  additional_service_source_ranges = var.additional_service_source_ranges

  labels = {
    environment = "dev"
    app         = "service-platform"
    managed_by  = "terraform"
  }
}
