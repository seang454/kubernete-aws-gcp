output "control_plane_nodes" {
  description = "DigitalOcean control plane node details matching Kubespray inventory format."
  value = [
    for node in local.active_control_plane_nodes : {
      name             = node.name
      instance_name    = node.instance_name
      zone             = node.zone
      machine_type     = node.machine_type
      public_ip        = var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
      private_ip       = digitalocean_droplet.this[node.name].ipv4_address_private != null && digitalocean_droplet.this[node.name].ipv4_address_private != "" ? digitalocean_droplet.this[node.name].ipv4_address_private : digitalocean_droplet.this[node.name].ipv4_address
      role             = "control_plane"
      cloud            = "digitalocean"
      etcd_member_name = node.name
    }
  ]
}

output "control_plane_public_ips" {
  description = "DigitalOcean control plane external IP addresses."
  value = [
    for node in local.active_control_plane_nodes :
    var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
  ]
}

output "control_plane_private_ips" {
  description = "DigitalOcean control plane internal IP addresses."
  value = [
    for node in local.active_control_plane_nodes :
    digitalocean_droplet.this[node.name].ipv4_address_private != null && digitalocean_droplet.this[node.name].ipv4_address_private != "" ? digitalocean_droplet.this[node.name].ipv4_address_private : digitalocean_droplet.this[node.name].ipv4_address
  ]
}

output "worker_nodes" {
  description = "DigitalOcean worker node details matching Kubespray inventory format."
  value = [
    for node in local.active_worker_nodes : {
      name             = node.name
      instance_name    = node.instance_name
      zone             = node.zone
      machine_type     = node.machine_type
      public_ip        = var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
      private_ip       = digitalocean_droplet.this[node.name].ipv4_address_private != null && digitalocean_droplet.this[node.name].ipv4_address_private != "" ? digitalocean_droplet.this[node.name].ipv4_address_private : digitalocean_droplet.this[node.name].ipv4_address
      role             = "worker"
      cloud            = "digitalocean"
      etcd_member_name = null
    }
  ]
}

output "worker_public_ips" {
  description = "DigitalOcean worker external IP addresses."
  value = [
    for node in local.active_worker_nodes :
    var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
  ]
}

output "worker_private_ips" {
  description = "DigitalOcean worker internal IP addresses."
  value = [
    for node in local.active_worker_nodes :
    digitalocean_droplet.this[node.name].ipv4_address_private != null && digitalocean_droplet.this[node.name].ipv4_address_private != "" ? digitalocean_droplet.this[node.name].ipv4_address_private : digitalocean_droplet.this[node.name].ipv4_address
  ]
}

output "cluster_public_ips" {
  description = "All public IP addresses for DigitalOcean droplets."
  value = concat(
    [
      for node in local.active_control_plane_nodes :
      var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
    ],
    [
      for node in local.active_worker_nodes :
      var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
    ]
  )
}

output "all_nodes" {
  description = "All active DigitalOcean Kubernetes node details keyed by Kubespray inventory hostname."
  value = {
    for node in local.active_nodes : node.name => {
      instance_name = node.instance_name
      role          = node.role
      zone          = node.zone
      machine_type  = node.machine_type
      public_ip     = var.allocate_reserved_ips ? digitalocean_reserved_ip.this[node.name].ip_address : digitalocean_droplet.this[node.name].ipv4_address
      private_ip    = digitalocean_droplet.this[node.name].ipv4_address_private != null && digitalocean_droplet.this[node.name].ipv4_address_private != "" ? digitalocean_droplet.this[node.name].ipv4_address_private : digitalocean_droplet.this[node.name].ipv4_address
      cloud         = "digitalocean"
    }
  }
}

output "droplet_ids" {
  description = "List of created DigitalOcean Droplet IDs."
  value       = [for d in digitalocean_droplet.this : d.id]
}

output "firewall_id" {
  description = "DigitalOcean Firewall ID."
  value       = try(digitalocean_firewall.k8s[0].id, null)
}

output "ssh_key_id" {
  description = "DigitalOcean SSH key ID."
  value       = try(digitalocean_ssh_key.this[0].id, null)
}

output "ssh_key_fingerprint" {
  description = "DigitalOcean SSH key fingerprint."
  value       = try(digitalocean_ssh_key.this[0].fingerprint, null)
}

output "usable_regions" {
  description = "Final DigitalOcean regions Terraform can use after discovery and blocked filters."
  value       = local.usable_regions
}

output "discovered_up_regions" {
  description = "DigitalOcean regions reported available."
  value       = local.discovered_up_regions
}

output "candidate_regions" {
  description = "Candidate DigitalOcean regions before blocked filter."
  value       = local.candidate_regions
}

output "usable_fallback_machines" {
  description = "Usable fallback Droplet sizes after blocked filters."
  value       = local.usable_fallback_machines
}

output "machine_plan" {
  description = "All planned DigitalOcean nodes."
  value       = local.all_nodes
}

output "stopped_nodes" {
  description = "DigitalOcean nodes currently powered off via stop_nodes or desired_status."
  value       = var.desired_status == "TERMINATED" ? [for n in local.active_nodes : n.instance_name] : var.stop_nodes
}

output "excluded_nodes" {
  description = "DigitalOcean nodes permanently excluded (deleted) via exclude_nodes."
  value       = var.exclude_nodes
}
