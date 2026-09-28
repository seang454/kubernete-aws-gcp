output "instance_names" {
  description = "All AWS EC2 instance names."
  value       = [for instance in aws_instance.this : instance.tags["Name"]]
}

output "instance_ids" {
  description = "All AWS EC2 instance IDs."
  value       = [for instance in aws_instance.this : instance.id]
}

output "server_ips" {
  description = "All public IP addresses for Ansible inventory (Elastic IPs or instance public IPs)."
  value = var.allocate_elastic_ips ? [
    for eip in aws_eip.this : eip.public_ip
  ] : [
    for instance in aws_instance.this : instance.public_ip
  ]
}

output "server_ip" {
  description = "First public IP address."
  value = length(aws_instance.this) > 0 ? (
    var.allocate_elastic_ips && length(aws_eip.this) > 0 ? aws_eip.this[0].public_ip : aws_instance.this[0].public_ip
  ) : ""
}

output "private_ips" {
  description = "Private IP addresses of EC2 instances."
  value       = [for instance in aws_instance.this : instance.private_ip]
}

output "ssh_user" {
  description = "SSH user for connecting to EC2 instances."
  value       = var.ssh_user
}

output "http_urls" {
  description = "Public HTTP URLs for all instances."
  value = [
    for ip in (var.allocate_elastic_ips ? [for e in aws_eip.this : e.public_ip] : [for i in aws_instance.this : i.public_ip]) :
    "http://${ip}"
  ]
}

output "https_urls" {
  description = "Public HTTPS URLs for all instances."
  value = [
    for ip in (var.allocate_elastic_ips ? [for e in aws_eip.this : e.public_ip] : [for i in aws_instance.this : i.public_ip]) :
    "https://${ip}"
  ]
}

output "instances" {
  description = "VM details keyed by instance name."
  value = {
    for index, instance in aws_instance.this : instance.tags["Name"] => {
      cloud        = "aws"
      zone         = instance.availability_zone
      machine_type = instance.instance_type
      static_ip    = var.allocate_elastic_ips && length(aws_eip.this) > index ? aws_eip.this[index].public_ip : instance.public_ip
      public_ip    = var.allocate_elastic_ips && length(aws_eip.this) > index ? aws_eip.this[index].public_ip : instance.public_ip
      private_ip   = instance.private_ip
      http_url     = "http://${var.allocate_elastic_ips && length(aws_eip.this) > index ? aws_eip.this[index].public_ip : instance.public_ip}"
      https_url    = "https://${var.allocate_elastic_ips && length(aws_eip.this) > index ? aws_eip.this[index].public_ip : instance.public_ip}"
    }
  }
}
