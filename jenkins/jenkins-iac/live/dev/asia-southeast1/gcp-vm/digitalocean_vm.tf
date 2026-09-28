module "digitalocean_vm" {
  source = "../../../../modules/digitalocean-vm"

  enabled        = var.enable_digitalocean
  name           = "do-vm"
  instance_count = local.effective_do_instance_count
  index_offset   = local.effective_gcp_instance_count + local.effective_aws_instance_count

  region                   = var.digitalocean_region
  regions                  = var.digitalocean_regions
  fallback_regions         = var.digitalocean_fallback_regions
  auto_discover_up_regions = var.digitalocean_auto_discover_up_regions
  blocked_regions          = var.digitalocean_blocked_regions
  sizes                    = var.digitalocean_sizes
  fallback_sizes           = var.digitalocean_fallback_sizes
  blocked_sizes            = var.digitalocean_blocked_sizes
  random_resource_type     = var.digitalocean_random_resource_type
  image                    = var.digitalocean_image

  ssh_user            = var.digitalocean_ssh_user
  ssh_public_key      = local.ssh_public_key
  ssh_public_key_path = var.ssh_public_key_path

  allocate_reserved_ips            = var.digitalocean_allocate_reserved_ips
  ssh_source_ranges                = var.ssh_source_ranges
  public_service_ports             = var.public_service_ports
  public_service_source_ranges     = var.public_service_source_ranges
  additional_service_ports         = var.additional_service_ports
  additional_service_source_ranges = var.additional_service_source_ranges

  tags = ["dev", "service-platform", "managed-by-terraform"]
}
