# backend.gcs.hcl stores backend values such as bucket and prefix.
# Terraform reads it during:
# terraform init -backend-config=backend.gcs.hcl
# so the gernerated value will be stored in terraform.tfstate file not in this file.so backend "gcs"{} still the same as before, but the values are read from backend.gcs.hcl file.

terraform {
  # Supply bucket and prefix from backend.gcs.hcl during terraform init.
  backend "gcs" {}
}
#This means: This Terraform stack will use Google Cloud Storage to store its state.