variable "project_id" {
  description = "GCP project ID."
  type        = string
  default     = "project-469c6b81-55a1-4508-830"
}

variable "region" {
  description = "GCP region for the GCS state bucket."
  type        = string
  default     = "asia-southeast1"
}

variable "bucket_name" {
  description = "Optional explicit custom bucket name. If empty, Terraform auto-generates a globally unique bucket name."
  type        = string
  default     = ""
}

variable "bucket_name_prefix" {
  description = "Prefix used to generate the GCS state bucket name when bucket_name is empty."
  type        = string
  default     = "tfstate"
}

variable "gcp_adc_file" {
  description = "Optional ADC JSON path. Leave empty for automatic per-user ADC discovery."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_versioning" {
  description = "Enable object versioning on the GCS state bucket for recovery and safety."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Set to true to allow Terraform to delete the bucket even if it contains state files."
  type        = bool
  default     = false
}
