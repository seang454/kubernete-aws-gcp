output "control_plane_nodes" {
  description = "GCP control plane nodes with public and private IPs."
  value       = module.gcp_kubespray_cluster.control_plane_nodes
}

output "gcp_worker_nodes" {
  description = "GCP worker nodes (if any) with public and private IPs."
  value       = module.gcp_kubespray_cluster.worker_nodes
}

output "aws_worker_nodes" {
  description = "AWS worker nodes with public and private IPs."
  value       = module.aws_kubespray_workers.worker_nodes
}

output "worker_nodes" {
  description = "All worker nodes across GCP and AWS with public and private IPs."
  value       = local.all_worker_nodes
}

output "all_nodes" {
  description = "All active Kubernetes nodes keyed by Kubespray inventory hostname."
  value = merge(
    module.gcp_kubespray_cluster.all_nodes,
    { for node in module.aws_kubespray_workers.worker_nodes : node.name => {
      instance_name = node.instance_name
      role          = "worker"
      zone          = node.zone
      machine_type  = node.machine_type
      public_ip     = node.public_ip
      private_ip    = node.private_ip
      cloud         = "aws"
    } }
  )
}

output "control_plane_public_ips" {
  description = "Control plane external IP addresses (GCP)."
  value       = module.gcp_kubespray_cluster.control_plane_public_ips
}

output "worker_public_ips" {
  description = "Worker external IP addresses (AWS + GCP)."
  value = concat(
    module.gcp_kubespray_cluster.worker_public_ips,
    module.aws_kubespray_workers.worker_public_ips
  )
}

output "control_plane_private_ips" {
  description = "Control plane internal IP addresses (GCP)."
  value       = module.gcp_kubespray_cluster.control_plane_private_ips
}

output "worker_private_ips" {
  description = "Worker internal IP addresses (AWS + GCP)."
  value = concat(
    module.gcp_kubespray_cluster.worker_private_ips,
    module.aws_kubespray_workers.worker_private_ips
  )
}

output "machine_plan" {
  description = "Terraform-computed node plan across both GCP and AWS before resource creation."
  value = concat(
    module.gcp_kubespray_cluster.machine_plan,
    module.aws_kubespray_workers.machine_plan
  )
}

output "usable_zones" {
  description = "Final GCP zones Terraform can use after discovery and blocked filters."
  value       = module.gcp_kubespray_cluster.usable_zones
}

output "aws_security_group_id" {
  description = "AWS worker security group ID."
  value       = module.aws_kubespray_workers.security_group_id
}

output "aws_key_pair_name" {
  description = "AWS key pair name."
  value       = module.aws_kubespray_workers.key_pair_name
}

output "aws_usable_zones" {
  description = "Final AWS availability zones Terraform can use after discovery and blocked filters."
  value       = module.aws_kubespray_workers.usable_zones
}

output "aws_discovered_up_zones" {
  description = "AWS availability zones reported in 'available' state."
  value       = module.aws_kubespray_workers.discovered_up_zones
}

output "aws_usable_fallback_machines" {
  description = "Usable fallback EC2 machine types after blocked filters."
  value       = module.aws_kubespray_workers.usable_fallback_machines
}

output "kubespray_inventory_path" {
  description = "Generated Kubespray inventory file path."
  value       = local_file.kubespray_inventory.filename
}

output "wireguard_inventory_path" {
  description = "Generated WireGuard Full Mesh inventory file path."
  value       = local_file.wireguard_inventory.filename
}

output "excluded_nodes" {
  description = "Node names currently excluded (permanently deleted) from the cluster."
  value       = var.exclude_nodes
}

output "stopped_nodes" {
  description = "Node names currently stopped (powered off) without deletion."
  value       = var.stop_nodes
}

output "running_worker_nodes" {
  description = "Worker nodes currently running and included in the Kubespray inventory."
  value       = local.active_inventory_workers
}

output "running_control_plane_nodes" {
  description = "Control plane nodes currently running and included in the Kubespray inventory."
  value       = local.active_inventory_control_planes
}
