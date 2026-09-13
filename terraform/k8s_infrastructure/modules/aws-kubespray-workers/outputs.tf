output "control_plane_nodes" {
  description = "AWS control plane node details matching Kubespray inventory format."
  value = [
    for node in local.active_control_plane_nodes : {
      name             = node.name
      instance_name    = node.instance_name
      zone             = node.zone
      machine_type     = node.machine_type
      public_ip        = var.allocate_elastic_ips ? aws_eip.this[node.name].public_ip : aws_instance.this[node.name].public_ip
      private_ip       = aws_instance.this[node.name].private_ip
      role             = "control_plane"
      cloud            = "aws"
      etcd_member_name = node.name
    }
  ]
}

output "control_plane_public_ips" {
  description = "AWS control plane external IP addresses."
  value = [
    for node in local.active_control_plane_nodes :
    var.allocate_elastic_ips ? aws_eip.this[node.name].public_ip : aws_instance.this[node.name].public_ip
  ]
}

output "control_plane_private_ips" {
  description = "AWS control plane internal IP addresses."
  value = [
    for node in local.active_control_plane_nodes :
    aws_instance.this[node.name].private_ip
  ]
}

output "worker_nodes" {
  description = "AWS worker node details matching Kubespray inventory format."
  value = [
    for node in local.active_worker_nodes : {
      name             = node.name
      instance_name    = node.instance_name
      zone             = node.zone
      machine_type     = node.machine_type
      public_ip        = var.allocate_elastic_ips ? aws_eip.this[node.name].public_ip : aws_instance.this[node.name].public_ip
      private_ip       = aws_instance.this[node.name].private_ip
      role             = "worker"
      cloud            = "aws"
      etcd_member_name = null
    }
  ]
}

output "worker_public_ips" {
  description = "AWS worker external IP addresses."
  value = [
    for node in local.active_worker_nodes :
    var.allocate_elastic_ips ? aws_eip.this[node.name].public_ip : aws_instance.this[node.name].public_ip
  ]
}

output "worker_private_ips" {
  description = "AWS worker internal IP addresses."
  value = [
    for node in local.active_worker_nodes :
    aws_instance.this[node.name].private_ip
  ]
}

output "security_group_id" {
  description = "AWS worker security group ID."
  value       = aws_security_group.worker.id
}

output "key_pair_name" {
  description = "AWS key pair name."
  value       = try(aws_key_pair.this[0].key_name, null)
}

output "all_nodes" {
  description = "All active AWS Kubernetes node details keyed by Kubespray inventory hostname."
  value = {
    for node in local.active_nodes : node.name => {
      instance_name = node.instance_name
      role          = node.role
      zone          = node.zone
      machine_type  = node.machine_type
      public_ip     = var.allocate_elastic_ips ? aws_eip.this[node.name].public_ip : aws_instance.this[node.name].public_ip
      private_ip    = aws_instance.this[node.name].private_ip
      cloud         = "aws"
    }
  }
}

output "machine_plan" {
  description = "All planned AWS nodes."
  value       = local.all_nodes
}

output "usable_zones" {
  description = "Final AWS availability zones Terraform can use after discovery and blocked filters."
  value       = local.usable_zones
}

output "discovered_up_zones" {
  description = "AWS availability zones reported in 'available' state."
  value       = local.discovered_up_zones
}

output "candidate_zones" {
  description = "Candidate AWS availability zones before blocked filter."
  value       = local.candidate_zones
}

output "usable_fallback_machines" {
  description = "Usable fallback EC2 machine types after blocked filters."
  value       = local.usable_fallback_machines
}

output "excluded_nodes" {
  description = "Node names currently excluded from AWS."
  value       = [for name in var.exclude_nodes : name if contains([for n in local.all_nodes : n.instance_name], name)]
}

output "stopped_nodes" {
  description = "Node names currently stopped (powered off) in AWS without deletion."
  value       = [for name in var.stop_nodes : name if contains([for n in local.all_nodes : n.instance_name], name)]
}
