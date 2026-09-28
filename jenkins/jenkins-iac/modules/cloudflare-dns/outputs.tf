output "records" {
  description = "Cloudflare DNS records keyed by local Terraform name."
  value = {
    for key, record in cloudflare_dns_record.this : key => {
      id      = record.id
      name    = record.name
      type    = record.type
      content = record.content
      proxied = record.proxied
      ttl     = record.ttl
    }
  }
}

output "hostnames" {
  description = "DNS record hostnames."
  value       = [for record in cloudflare_dns_record.this : record.name]
}
