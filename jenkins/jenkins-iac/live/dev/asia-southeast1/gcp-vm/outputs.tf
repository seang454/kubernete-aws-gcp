# ---------------------------------------------------------------------------
# Multi-Cloud Outputs
# ---------------------------------------------------------------------------

output "instance_names" {
  description = "All instance names across all active clouds."
  value       = local.all_instance_names
}

output "server_ips" {
  description = "All public/static server IPs across all active clouds."
  value       = local.all_server_ips
}

output "server_ip" {
  description = "First public IP address."
  value       = try(local.all_server_ips[0], "")
}

output "http_url" {
  description = "First VM public HTTP URL."
  value       = length(local.all_server_ips) > 0 ? "http://${local.all_server_ips[0]}" : ""
}

output "http_urls" {
  description = "Public HTTP URLs for all instances across all clouds."
  value       = [for ip in local.all_server_ips : "http://${ip}"]
}

output "https_url" {
  description = "First VM public HTTPS URL."
  value       = length(local.all_server_ips) > 0 ? "https://${local.all_server_ips[0]}" : ""
}

output "https_urls" {
  description = "Public HTTPS URLs for all instances across all clouds."
  value       = [for ip in local.all_server_ips : "https://${ip}"]
}

output "instances" {
  description = "Unified VM details keyed by instance name across all clouds."
  value       = local.all_instances
}

# ---------------------------------------------------------------------------
# Provider Specific Breakdowns
# ---------------------------------------------------------------------------

output "gcp_instances" {
  description = "GCP VM details."
  value       = module.gcp_vm.instances
}

output "aws_instances" {
  description = "AWS EC2 instance details."
  value       = module.aws_vm.instances
}

output "digitalocean_instances" {
  description = "DigitalOcean Droplet details."
  value       = module.digitalocean_vm.instances
}

# ---------------------------------------------------------------------------
# Ansible & Cloudflare Outputs
# ---------------------------------------------------------------------------

output "ansible_inventory_path" {
  description = "Generated Ansible inventory file path."
  value       = local_file.ansible_inventory.filename
}

output "ansible_group_vars_domain_files" {
  description = "Generated Ansible group_vars domain files."
  value       = { for group, file in local_file.ansible_group_vars_domains : group => file.filename }
}

output "cloudflare_dns_records" {
  description = "Cloudflare DNS records created by Terraform."
  value       = var.enable_cloudflare_dns ? module.cloudflare_dns[0].records : {}
}

output "cloudflare_hostnames" {
  description = "Cloudflare hostnames created by Terraform."
  value       = var.enable_cloudflare_dns ? module.cloudflare_dns[0].hostnames : []
}
