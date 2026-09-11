output "bucket_name" {
  description = "The name of the generated GCS bucket for Terraform state."
  value       = google_storage_bucket.tfstate.name
}

output "bucket_url" {
  description = "The GCS URL of the state bucket."
  value       = google_storage_bucket.tfstate.url
}

output "backend_hcl_snippet" {
  description = "Paste this block into your kubespray-k8s backend.tf to use this GCS remote backend."
  value       = <<EOT
terraform {
  backend "gcs" {
    bucket = "${google_storage_bucket.tfstate.name}"
    prefix = "dev/asia-southeast1/kubespray-k8s"
  }
}
EOT
}
