terraform {
  required_version = ">= 1.4.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Empty uses automatic ADC discovery for whichever user runs Terraform.
  # pathexpand lets an optional "~/.config/..." path use the current user.
  credentials = trimspace(var.gcp_adc_file) != "" ? file(pathexpand(trimspace(var.gcp_adc_file))) : null
}
