#!/bin/bash
set -e

TFVARS_FILE="terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
  echo "Error: terraform.tfvars file not found in current directory!"
  exit 1
fi

USE_GCS=$(grep -E '^\s*use_gcs_backend\s*=' "$TFVARS_FILE" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "' | tr '[:upper:]' '[:lower:]')
BUCKET=$(grep -E '^\s*gcs_bucket_name\s*=' "$TFVARS_FILE" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')
LOCAL_PATH=$(grep -E '^\s*local_state_path\s*=' "$TFVARS_FILE" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')

if [ -z "$LOCAL_PATH" ]; then
  LOCAL_PATH="../../../../state/dev/asia-southeast1/kubespray-k8s.tfstate"
fi

if [ "$USE_GCS" = "true" ]; then
  if [ -z "$BUCKET" ]; then
    echo "Error: use_gcs_backend is set to true, but gcs_bucket_name is empty in terraform.tfvars!"
    echo "Please set gcs_bucket_name = \"your-bucket-name\" in terraform.tfvars."
    exit 1
  fi
  echo "=========================================================="
  echo "Backend Mode: GCS Cloud Storage (Bucket: $BUCKET)"
  echo "=========================================================="
  cat <<EOF > backend.tf
terraform {
  backend "gcs" {}
}
EOF
  cat <<EOF > backend_gcs.hcl
bucket = "$BUCKET"
prefix = "dev/asia-southeast1/kubespray-k8s"
EOF
  terraform init -backend-config=backend_gcs.hcl -reconfigure "$@"
else
  echo "=========================================================="
  echo "Backend Mode: Local Filesystem Storage"
  echo "Path: $LOCAL_PATH"
  echo "=========================================================="
  cat <<EOF > backend.tf
terraform {
  backend "local" {
    path = "$LOCAL_PATH"
  }
}
EOF
  terraform init -reconfigure "$@"
fi
