variable "zone_id" {
  description = "Cloudflare zone ID where DNS records are created."
  type        = string

  validation {
    condition     = trimspace(var.zone_id) != ""
    error_message = "zone_id cannot be empty."
  }
}

variable "records" {
  description = "Cloudflare DNS records keyed by a stable Terraform name."
  type = map(object({
    name    = string
    content = string
    type    = optional(string, "A")
    ttl     = optional(number, 1)
    proxied = optional(bool, false)
    comment = optional(string, "Managed by Terraform")
  }))
  default = {}

  validation {
    condition     = alltrue([for _, record in var.records : trimspace(record.name) != ""])
    error_message = "Each Cloudflare DNS record name must be non-empty."
  }

  validation {
    condition     = alltrue([for _, record in var.records : trimspace(record.content) != ""])
    error_message = "Each Cloudflare DNS record content value must be non-empty."
  }

  validation {
    condition     = alltrue([for _, record in var.records : contains(["A", "AAAA", "CNAME"], record.type)])
    error_message = "Cloudflare DNS record type must be A, AAAA, or CNAME."
  }

  validation {
    condition     = alltrue([for _, record in var.records : try(record.ttl == 1 || (record.ttl >= 60 && record.ttl <= 86400), false)])
    error_message = "Cloudflare DNS record ttl must be 1 for automatic, or between 60 and 86400 seconds."
  }
}
