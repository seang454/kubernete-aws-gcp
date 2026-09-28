terraform {
  # Keep bootstrap state local. This stack only creates the GCS backend bucket.
  backend "local" {}

  required_version = ">= 1.4.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID where Terraform will create the bootstrap bucket."
  type        = string

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "bucket_name" {
  description = "GCS bucket name used for Terraform state."
  type        = string
  default     = "parryhot-tf-state-dev-992"
}

variable "bucket_location" {
  description = "Location for the Terraform state bucket."
  type        = string
  default     = "asia-southeast1"
}

variable "gcp_adc_file" {
  description = "Optional ADC JSON path. Leave empty for automatic ADC discovery."
  type        = string
  default     = ""
  sensitive   = true
}

variable "force_destroy" {
  description = "When set to true, allows Terraform to delete all state files and destroy the GCS bucket."
  type        = bool
  default     = false
}

provider "google" {
  project = var.project_id

  credentials = trimspace(var.gcp_adc_file) != "" ? file(pathexpand(trimspace(var.gcp_adc_file))) : null
}

resource "google_storage_bucket" "terraform_state" {
  name                        = var.bucket_name
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false
  }

  labels = {
    managed_by = "terraform"
    purpose    = "state"
    stack      = "bootstrap"
  }
}

output "bucket_name" {
  description = "State bucket name."
  value       = google_storage_bucket.terraform_state.name
}

output "bucket_location" {
  description = "State bucket location."
  value       = google_storage_bucket.terraform_state.location
}
