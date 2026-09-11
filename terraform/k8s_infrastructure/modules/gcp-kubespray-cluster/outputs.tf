output "control_plane_nodes" {
  description = "Kubespray control plane node details."
  value = [
    for node in local.active_control_plane_nodes : {
      name             = node.name
      instance_name    = node.instance_name
      zone             = node.zone
      machine_type     = node.machine_type
      public_ip        = one(google_compute_instance.this[node.name].network_interface[0].access_config[*].nat_ip)
      private_ip       = google_compute_instance.this[node.name].network_interface[0].network_ip
      etcd_member_name = node.name
    }
  ]
}

output "worker_nodes" {
  description = "Kubespray worker node details."
  value = [
    for node in local.active_worker_nodes : {
      name          = node.name
      instance_name = node.instance_name
      zone          = node.zone
      machine_type  = node.machine_type
      public_ip     = one(google_compute_instance.this[node.name].network_interface[0].access_config[*].nat_ip)
      private_ip    = google_compute_instance.this[node.name].network_interface[0].network_ip
    }
  ]
}

output "nfs_nodes" {
  description = "NFS / Ceph storage node details."
  value = [
    for node in local.active_nfs_nodes : {
      name          = node.name
      instance_name = node.instance_name
      zone          = node.zone
      machine_type  = node.machine_type
      public_ip     = one(google_compute_instance.this[node.name].network_interface[0].access_config[*].nat_ip)
      private_ip    = google_compute_instance.this[node.name].network_interface[0].network_ip
    }
  ]
}

output "all_nodes" {
  description = "All active Kubernetes node details keyed by Kubespray inventory hostname."
  value = {
    for node in local.active_nodes : node.name => {
      instance_name = node.instance_name
      role          = node.role
      zone          = node.zone
      machine_type  = node.machine_type
      public_ip     = one(google_compute_instance.this[node.name].network_interface[0].access_config[*].nat_ip)
      private_ip    = google_compute_instance.this[node.name].network_interface[0].network_ip
    }
  }
}

output "control_plane_public_ips" {
  description = "Control plane external IP addresses."
  value       = [for node in local.active_control_plane_nodes : one(google_compute_instance.this[node.name].network_interface[0].access_config[*].nat_ip)]
}

output "worker_public_ips" {
  description = "Worker external IP addresses."
  value       = [for node in local.active_worker_nodes : one(google_compute_instance.this[node.name].network_interface[0].access_config[*].nat_ip)]
}

output "control_plane_private_ips" {
  description = "Control plane internal IP addresses."
  value       = [for node in local.active_control_plane_nodes : google_compute_instance.this[node.name].network_interface[0].network_ip]
}

output "worker_private_ips" {
  description = "Worker internal IP addresses."
  value       = [for node in local.active_worker_nodes : google_compute_instance.this[node.name].network_interface[0].network_ip]
}

output "excluded_nodes" {
  description = "Node names currently excluded (deleted) from the cluster."
  value       = var.exclude_nodes
}

output "usable_zones" {
  description = "Final zones Terraform can use after discovery and blocked filters."
  value       = local.usable_zones
}

output "machine_plan" {
  description = "Terraform-computed Kubernetes node plan (full pool including excluded nodes)."
  value       = local.nodes
}

output "ssh_user" {
  description = "SSH user configured on all nodes."
  value       = var.ssh_user
}
