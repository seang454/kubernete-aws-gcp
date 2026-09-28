locals {
  # Calculate effective instance counts for each cloud
  effective_gcp_instance_count = var.enable_gcp ? (var.gcp_instance_count != null ? var.gcp_instance_count : var.instance_count) : 0
  effective_aws_instance_count = var.enable_aws ? var.aws_instance_count : 0
  effective_do_instance_count  = var.enable_digitalocean ? var.digitalocean_instance_count : 0

  # Total instance counts across all providers
  total_instance_count = local.effective_gcp_instance_count + local.effective_aws_instance_count + local.effective_do_instance_count

  # Aggregated instance names from all active clouds
  all_instance_names = concat(
    module.gcp_vm.instance_names,
    module.aws_vm.instance_names,
    module.digitalocean_vm.instance_names
  )

  # Aggregated public/static server IPs from all active clouds
  all_server_ips = concat(
    module.gcp_vm.server_ips,
    module.aws_vm.server_ips,
    module.digitalocean_vm.server_ips
  )

  # Aggregated SSH users matching the order of all_instance_names
  all_ssh_users = concat(
    [for _ in module.gcp_vm.instance_names : module.gcp_vm.ssh_user],
    [for _ in module.aws_vm.instance_names : module.aws_vm.ssh_user],
    [for _ in module.digitalocean_vm.instance_names : module.digitalocean_vm.ssh_user]
  )

  # Unified instances dictionary
  all_instances = merge(
    module.gcp_vm.instances,
    module.aws_vm.instances,
    module.digitalocean_vm.instances
  )
}
