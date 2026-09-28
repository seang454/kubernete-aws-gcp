locals {
  cloudflare_dns_records = {
    for key, record in var.cloudflare_dns_records : key => {
      name = record.hostname
      content = (
        try(trimspace(record.content), "") != ""
        ? trimspace(record.content)
        : try(local.all_server_ips[record.vm_index - 1], "0.0.0.0")
      )
      type    = upper(record.type)
      ttl     = record.ttl
      proxied = record.proxied
      comment = coalesce(
        try(record.comment, null),
        "Managed by Terraform: ${record.hostname}"
      )
    } if try(record.enabled, true) && (try(trimspace(record.content), "") != "" || try(record.vm_index > 0, true))
  }
}

resource "terraform_data" "cloudflare_dns_preflight" {
  count = var.enable_cloudflare_dns ? 1 : 0

  input = var.cloudflare_dns_records

  lifecycle {
    precondition {
      condition     = trimspace(var.cloudflare_zone_id) != ""
      error_message = "Set cloudflare_zone_id before enabling Cloudflare DNS."
    }

    precondition {
      condition     = length(var.cloudflare_dns_records) > 0
      error_message = "Set at least one cloudflare_dns_records entry before enabling Cloudflare DNS."
    }

    precondition {
      condition = alltrue([
        for _, record in var.cloudflare_dns_records :
        try(record.enabled, true) == false ||
        try(record.vm_index, null) == 0 ||
        upper(record.type) == "CNAME" ||
        try(trimspace(record.content), "") != "" ||
        try(record.vm_index >= 1 && record.vm_index <= length(local.all_server_ips), false)
      ])
      error_message = "Each vm_index must point to an existing VM across all clouds (or 0 to disable). Example: vm_index = 1 uses VM 1."
    }
  }
}

module "cloudflare_dns" {
  count = var.enable_cloudflare_dns ? 1 : 0

  source  = "../../../../modules/cloudflare-dns"
  zone_id = var.cloudflare_zone_id
  records = local.cloudflare_dns_records

  depends_on = [terraform_data.cloudflare_dns_preflight]
}
