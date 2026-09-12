terraform {
  required_version = ">= 1.4.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }

    aws = {
      source  = "hashicorp/aws"
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

provider "aws" {
  region  = var.aws_region
  profile = trimspace(var.aws_profile) != "" ? var.aws_profile : null

  # Custom credential / config file paths configured from terraform.tfvars
  # Leave empty ("") to use automatic SDK discovery (~/.aws/credentials)
  shared_credentials_files = trimspace(var.aws_shared_credentials_file) != "" ? [pathexpand(trimspace(var.aws_shared_credentials_file))] : null
  shared_config_files      = trimspace(var.aws_shared_config_file) != "" ? [pathexpand(trimspace(var.aws_shared_config_file))] : null

  # Credentials fallback automatically to standard AWS environment variables
  # (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) or ~/.aws credentials
  access_key = trimspace(var.aws_access_key) != "" ? var.aws_access_key : null
  secret_key = trimspace(var.aws_secret_key) != "" ? var.aws_secret_key : null
  token      = trimspace(var.aws_session_token) != "" ? var.aws_session_token : null

  default_tags {
    tags = {
      environment = "dev"
      app         = "kubespray"
      managed_by  = "terraform"
      cluster     = var.cluster_name
    }
  }
}
