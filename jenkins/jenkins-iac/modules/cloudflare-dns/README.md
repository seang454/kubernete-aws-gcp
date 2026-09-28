# Cloudflare DNS Module

This module creates Cloudflare DNS records, usually pointing service subdomains to Terraform-created VM external IPs.

Example:

```hcl
module "cloudflare_dns" {
  source  = "../../../../modules/cloudflare-dns"
  zone_id = var.cloudflare_zone_id

  records = {
    jenkins = {
      name    = "jenkins.seang.shop"
      content = "34.124.10.20"
      type    = "A"
      proxied = false
      ttl     = 1
    }
  }
}
```

CNAME example:

```hcl
records = {
  ci = {
    name    = "ci.seang.shop"
    content = "jenkins.seang.shop"
    type    = "CNAME"
    proxied = false
    ttl     = 1
  }
}
```

Use `proxied = false` when Ansible runs Certbot HTTP validation against the VM. After certificates work, you can choose whether Cloudflare proxying fits your service.
