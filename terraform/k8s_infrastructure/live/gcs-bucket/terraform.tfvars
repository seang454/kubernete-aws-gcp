project_id         = "project-469c6b81-55a1-4508-830"
region             = "asia-southeast1"

# Option 1: Specify an exact custom bucket name (must be globally unique across all GCP users)
# bucket_name      = "my-custom-kubespray-tfstate-bucket"

# Option 2: Specify a prefix (Terraform auto-appends project ID & unique random hex suffix)
bucket_name_prefix = "tfstate"

enable_versioning  = true
force_destroy      = false
gcp_adc_file       = ""
