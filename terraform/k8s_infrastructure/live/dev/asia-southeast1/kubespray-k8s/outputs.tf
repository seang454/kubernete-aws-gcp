output "control_plane_nodes" {
  description = "Control plane nodes with public and private IPs."
  value       = module.kubespray_cluster.control_plane_nodes
}

output "worker_nodes" {
  description = "Worker nodes with public and private IPs."
  value       = module.kubespray_cluster.worker_nodes
}

output "all_nodes" {
  description = "All Kubernetes nodes keyed by Kubespray inventory hostname."
  value       = module.kubespray_cluster.all_nodes
}

output "control_plane_public_ips" {
  description = "Control plane external IP addresses."
  value       = module.kubespray_cluster.control_plane_public_ips
}

output "worker_public_ips" {
  description = "Worker external IP addresses."
  value       = module.kubespray_cluster.worker_public_ips
}

output "control_plane_private_ips" {
  description = "Control plane internal IP addresses used by Kubespray ip=."
  value       = module.kubespray_cluster.control_plane_private_ips
}

output "worker_private_ips" {
  description = "Worker internal IP addresses used by Kubespray ip=."
  value       = module.kubespray_cluster.worker_private_ips
}

output "machine_plan" {
  description = "Terraform-computed node plan before resource creation."
  value       = module.kubespray_cluster.machine_plan
}

output "usable_zones" {
  description = "Final zones Terraform can use after discovery and blocked filters."
  value       = module.kubespray_cluster.usable_zones
}

output "kubespray_inventory_path" {
  description = "Generated Kubespray inventory file path."
  value       = local_file.kubespray_inventory.filename
}
