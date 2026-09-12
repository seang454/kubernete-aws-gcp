# Generate a unique 8-character hex suffix to ensure global GCS bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create dedicated Google Cloud Storage bucket for storing Terraform state files
resource "google_storage_bucket" "tfstate" {
  name     = trimspace(var.bucket_name) != "" ? trimspace(var.bucket_name) : "${var.project_id}-${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"
  location = var.region

  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.enable_versioning
  }

  labels = {
    environment = "dev"
    managed_by  = "terraform"
    purpose     = "tfstate-storage"
  }
}
