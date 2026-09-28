output "instance_names" {
  description = "All DigitalOcean Droplet names."
  value       = [for d in digitalocean_droplet.this : d.name]
}

output "server_ips" {
  description = "All public IP addresses for Ansible inventory."
  value = var.allocate_reserved_ips ? [
    for ip in digitalocean_reserved_ip.this : ip.ip_address
  ] : [
    for d in digitalocean_droplet.this : d.ipv4_address
  ]
}

output "server_ip" {
  description = "First public IP address."
  value = length(digitalocean_droplet.this) > 0 ? (
    var.allocate_reserved_ips && length(digitalocean_reserved_ip.this) > 0 ? digitalocean_reserved_ip.this[0].ip_address : digitalocean_droplet.this[0].ipv4_address
  ) : ""
}

output "ssh_user" {
  description = "SSH user for Droplet connection."
  value       = var.ssh_user
}

output "http_urls" {
  description = "Public HTTP URLs for all instances."
  value = [
    for ip in (var.allocate_reserved_ips ? [for r in digitalocean_reserved_ip.this : r.ip_address] : [for d in digitalocean_droplet.this : d.ipv4_address]) :
    "http://${ip}"
  ]
}

output "https_urls" {
  description = "Public HTTPS URLs for all instances."
  value = [
    for ip in (var.allocate_reserved_ips ? [for r in digitalocean_reserved_ip.this : r.ip_address] : [for d in digitalocean_droplet.this : d.ipv4_address]) :
    "https://${ip}"
  ]
}

output "instances" {
  description = "Droplet details keyed by instance name."
  value = {
    for index, d in digitalocean_droplet.this : d.name => {
      cloud        = "digitalocean"
      zone         = d.region
      machine_type = d.size
      static_ip    = var.allocate_reserved_ips && length(digitalocean_reserved_ip.this) > index ? digitalocean_reserved_ip.this[index].ip_address : d.ipv4_address
      public_ip    = var.allocate_reserved_ips && length(digitalocean_reserved_ip.this) > index ? digitalocean_reserved_ip.this[index].ip_address : d.ipv4_address
      http_url     = "http://${var.allocate_reserved_ips && length(digitalocean_reserved_ip.this) > index ? digitalocean_reserved_ip.this[index].ip_address : d.ipv4_address}"
      https_url    = "https://${var.allocate_reserved_ips && length(digitalocean_reserved_ip.this) > index ? digitalocean_reserved_ip.this[index].ip_address : d.ipv4_address}"
    }
  }
}
