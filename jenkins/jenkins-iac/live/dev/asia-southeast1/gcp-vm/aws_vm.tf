module "aws_vm" {
  source = "../../../../modules/aws-vm"

  enabled        = var.enable_aws
  name           = "aws-vm"
  instance_count = local.effective_aws_instance_count
  index_offset   = local.effective_gcp_instance_count

  region                 = var.aws_region
  zones                  = var.aws_availability_zones
  fallback_zones         = var.aws_fallback_zones
  auto_discover_up_zones = var.aws_auto_discover_up_zones
  blocked_zones          = var.aws_blocked_availability_zones
  machine_types          = var.aws_machine_types
  fallback_machine_types = var.aws_fallback_machine_types
  blocked_machine_types  = var.aws_blocked_machine_types
  random_resource_type   = var.aws_random_resource_type
  ami_id                 = var.aws_ami_id
  boot_disk_size_gb      = var.aws_boot_disk_size_gb
  boot_disk_type         = var.aws_boot_disk_type

  ssh_user            = var.aws_ssh_user
  ssh_public_key      = local.ssh_public_key
  ssh_public_key_path = var.ssh_public_key_path

  allocate_elastic_ips             = var.aws_allocate_elastic_ips
  ssh_source_ranges                = var.ssh_source_ranges
  public_service_ports             = var.public_service_ports
  public_service_source_ranges     = var.public_service_source_ranges
  additional_service_ports         = var.additional_service_ports
  additional_service_source_ranges = var.additional_service_source_ranges

  tags = {
    environment = "dev"
    app         = "service-platform"
    managed_by  = "terraform"
    cloud       = "aws"
  }
}
