# GCP VM Terraform Error Handling Flow

This project used to handle GCP VM creation errors with Ansible. Terraform handles the same idea differently because Terraform is declarative.

Terraform can:

- Build the machine plan before creation.
- Ask GCP for zones with status `UP` before building the VM plan.
- Remap from preferred zones to fallback regions when preferred zones are not usable.
- Skip zones and regions that you mark as blocked.
- Reserve static external IPs before creating VMs.
- Reuse the static IPs when VMs are recreated.
- Show the final VM names, zones, machine types, and IP addresses as outputs.

Terraform cannot:

- Catch `ZONE_RESOURCE_POOL_EXHAUSTED` inside the same `terraform apply`.
- Delete the failed VM and retry a different region automatically in the same run.
- Manage existing GCP instances that were created outside Terraform until you import them into Terraform state.

## Terraform Version Of Your Ansible Flow

| Old Ansible step | Terraform replacement |
| --- | --- |
| Build `machines_info` | `local.machines` in `modules/gcp-vm/main.tf` |
| Check configured zones | `data.google_compute_zones.available` with `status = "UP"` |
| Fetch fallback zones | `fallback_regions` plus `data.google_compute_zones.available` |
| Start stopped instances | `desired_status = "RUNNING"` for Terraform-managed VMs |
| Remap bad zones | Add bad zones/regions to `terraform.tfvars`, then rerun `terraform apply` |
| Reserve static IP | `google_compute_address.this` |
| Create VM with static IP | `google_compute_instance.this` uses the reserved IP |
| Merge final results | Terraform outputs `instances`, `machine_plan`, `server_ips`, and `https_urls` |

## Normal Apply

```powershell
cd terraform/infrastructure/live/dev/asia-southeast1/gcp-vm
terraform init
terraform plan
terraform apply
terraform output discovery_regions
terraform output discovered_up_zones
terraform output candidate_zones
terraform output machine_plan
terraform output instances
```

## Dynamic Zone Discovery

Keep this enabled in `terraform.tfvars`:

```hcl
auto_discover_up_zones = true
```

Terraform will ask GCP for zones with status `UP` in:

- the regions from your configured `zones`
- any extra `fallback_regions`

Example:

```hcl
zones = [
  "asia-southeast1-a",
  "asia-southeast1-b",
  "asia-southeast1-c"
]

fallback_regions = [
  "asia-east1",
  "asia-northeast1"
]
```

Terraform keeps your preferred zones first. If one preferred zone is not `UP`, Terraform can choose another UP zone from the same region or from `fallback_regions`.

## If A Zone Is Down

With `auto_discover_up_zones = true`, Terraform automatically removes zones that GCP does not report as `UP`.

If you want to force Terraform to skip `asia-southeast1-a`, edit `terraform.tfvars`:

```hcl
blocked_zones = [
  "asia-southeast1-a"
]
```

Then rerun:

```powershell
terraform plan
terraform apply
```

Terraform will skip that zone and use the remaining values in `zones`.

## If A Region Is Exhausted

If GCP returns `ZONE_RESOURCE_POOL_EXHAUSTED` for a whole region, add that region to `blocked_regions`.

```hcl
blocked_regions = [
  "asia-southeast1"
]
```

For this to work, your `zones` list must include zones from another region:

```hcl
zones = [
  "asia-southeast1-a",
  "asia-southeast1-b",
  "asia-southeast1-c",
  "asia-east1-a",
  "asia-east1-b"
]
```

Then rerun:

```powershell
terraform plan
terraform apply
```

## If A VM Already Exists

Terraform only manages resources that are in Terraform state. If the VM or static IP was created by Ansible or manually in GCP, import it before using Terraform to manage it.

Example for the first VM:

```powershell
terraform import "module.gcp_vm.google_compute_address.this[0]" "projects/YOUR_PROJECT_ID/regions/asia-southeast1/addresses/gcp-vm-1-ip"
terraform import "module.gcp_vm.google_compute_instance.this[0]" "projects/YOUR_PROJECT_ID/zones/asia-southeast1-a/instances/gcp-vm-1"
```

After importing:

```powershell
terraform plan
```

Check the plan carefully before applying.

## If A Terraform-Managed VM Is Stopped

Keep this value in `terraform.tfvars`:

```hcl
desired_status = "RUNNING"
```

Then run:

```powershell
terraform apply
```

Terraform will try to bring Terraform-managed VMs back to the desired running state.
