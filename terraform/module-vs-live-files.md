# Terraform Modules vs Live Files

This note explains the difference between Terraform files inside `modules/` and files inside `live/`.

## Short Idea

```text
modules/ = reusable recipe or template
live/    = real environment that uses the recipe
```

Example:

```text
modules/gcp-vm              = how to create a GCP VM
live/dev/.../gcp-vm         = create one real dev VM using that module
live/prod/.../gcp-vm        = create one real prod VM using that module
```

## Module Folder

Example:

```text
modules/gcp-vm/
|-- main.tf
|-- variables.tf
|-- outputs.tf
|-- versions.tf
|-- README.md
```

The module folder contains reusable Terraform code.

It answers:

```text
How do we create this kind of infrastructure?
```

For example:

```text
How do we create a GCP VM?
How do we create firewall rules?
How do we output the server IP?
```

## Live Folder

Example:

```text
live/dev/asia-southeast1/gcp-vm/
|-- backend.tf
|-- providers.tf
|-- main.tf
|-- variables.tf
|-- outputs.tf
|-- terraform.tfvars.example
|-- README.md
```

The live folder contains a real deployment.

It answers:

```text
Where and with what values do we deploy this infrastructure?
```

For example:

```text
Environment = dev
Region      = asia-southeast1
VM name     = dev-sonarqube
Machine     = e2-standard-2
```

## File Difference

| File | In `modules/` | In `live/` |
| --- | --- | --- |
| `main.tf` | Creates reusable resources, like `google_compute_instance`. | Calls the module and sends values into it. |
| `variables.tf` | Defines inputs the module needs. | Defines inputs the environment needs. |
| `outputs.tf` | Returns values from resources, like `server_ip`. | Returns values from the module. |
| `versions.tf` | Defines Terraform/provider version requirements for the module. | Sometimes replaced by `providers.tf`. |
| `backend.tf` | Usually not used. | Defines where Terraform state is stored. |
| `providers.tf` | Usually not used for credentials. | Configures provider, project, region, and credentials. |
| `terraform.tfvars.example` | Usually not used. | Example values for the environment. Copy to `terraform.tfvars`. |
| `README.md` | Explains how the module works. | Explains how to run that environment. |

## Example Flow

The value starts in `terraform.tfvars`:

```hcl
name = "dev-sonarqube"
zone = "asia-southeast1-a"
```

Then `live/dev/.../variables.tf` declares those inputs:

```hcl
variable "name" {
  type = string
}

variable "zone" {
  type = string
}
```

Then `live/dev/.../main.tf` sends the values into the module:

```hcl
module "gcp_vm" {
  source = "../../../../modules/gcp-vm"

  name = var.name
  zone = var.zone
}
```

Then `modules/gcp-vm/variables.tf` receives those values:

```hcl
variable "name" {
  type = string
}

variable "zone" {
  type = string
}
```

Then `modules/gcp-vm/main.tf` uses them to create the real resource:

```hcl
resource "google_compute_instance" "this" {
  name = var.name
  zone = var.zone
}
```

## Full Value Flow

```text
terraform.tfvars
    |
    v
live/.../variables.tf
    |
    v
live/.../main.tf
    |
    v
modules/gcp-vm/variables.tf
    |
    v
modules/gcp-vm/main.tf
    |
    v
GCP VM is created
```

## Why Variables Can Look Duplicate

You may see the same variable names in both places:

```text
live/dev/.../variables.tf
modules/gcp-vm/variables.tf
```

This is allowed because they are in different modules.

But this is not allowed:

```text
same variables.tf file has variable "name" twice
```

That would cause a duplicate variable error.

## Simple Comparison

Think about food:

```text
modules/ = recipe
live/    = order using the recipe
```

`modules/gcp-vm` says:

```text
Here is how to make a VM.
```

`live/dev/.../gcp-vm` says:

```text
Make a dev VM with this name, zone, size, and SSH key.
```

## Where To Run Terraform

Run Terraform from `live/`, not from `modules/`.

Example:

```powershell
cd D:\CSTADPreUniversityTraining\ITP\researchforinterview\terraform\infrastructure\live\dev\asia-southeast1\gcp-vm
terraform init
terraform plan
terraform apply
```

Do not normally run Terraform from:

```text
modules/gcp-vm
```

because modules are reusable building blocks, not real environment deployments.

## Short Summary

```text
modules/ = reusable building block
live/    = real environment deployment

modules/main.tf = creates resources
live/main.tf    = calls module

modules/variables.tf = module inputs
live/variables.tf    = environment inputs

modules/outputs.tf = module returns
live/outputs.tf    = environment returns
```

## What Must Match What?

This is the most important rule when a `live` folder calls a module.

Example from `live/dev/asia-southeast1/gcp-vm/main.tf`:

```hcl
module "gcp_vm" {
  source = "../../../../modules/gcp-vm"

  name         = var.name
  zone         = var.zone
  machine_type = var.machine_type
}
```

### Rule 1: Left Side Must Match Module Variables

The left side:

```hcl
name
zone
machine_type
```

must exist in:

```text
modules/gcp-vm/variables.tf
```

Example:

```hcl
variable "name" {
  type = string
}

variable "zone" {
  type = string
}

variable "machine_type" {
  type = string
}
```

So this:

```hcl
name = var.name
```

means:

```text
Send a value into the module variable called "name".
```

### Rule 2: Right Side Must Match Live Variables

The right side:

```hcl
var.name
var.zone
var.machine_type
```

must exist in the live folder:

```text
live/dev/asia-southeast1/gcp-vm/variables.tf
```

Example:

```hcl
variable "name" {
  type = string
}

variable "zone" {
  type = string
}

variable "machine_type" {
  type = string
}
```

So this:

```hcl
machine_type = var.machine_type
```

means:

```text
Take var.machine_type from the live folder and send it into the module variable called "machine_type".
```

### Rule 3: terraform.tfvars Must Match Live Variables

The values in:

```text
live/dev/asia-southeast1/gcp-vm/terraform.tfvars
```

must match variables declared in:

```text
live/dev/asia-southeast1/gcp-vm/variables.tf
```

Example `terraform.tfvars`:

```hcl
name         = "dev-sonarqube"
zone         = "asia-southeast1-a"
machine_type = "e2-standard-2"
```

These names must exist in live `variables.tf`:

```hcl
variable "name" {}
variable "zone" {}
variable "machine_type" {}
```

### Rule 4: Not Every Module Variable Must Be Passed

If a module variable has a default, the live `main.tf` does not need to pass it.

Example in `modules/gcp-vm/variables.tf`:

```hcl
variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}
```

Then this is okay:

```hcl
module "gcp_vm" {
  source = "../../../../modules/gcp-vm"

  name = var.name
  zone = var.zone
}
```

Terraform will use:

```text
machine_type = "e2-standard-2"
```

from the module default.

### Rule 5: Map Keys Do Not Need Separate Variables

Example:

```hcl
labels = {
  environment = "dev"
  app         = "sonarqube"
  managed_by  = "terraform"
}
```

The module only needs one variable:

```hcl
variable "labels" {
  type = map(string)
}
```

It does not need separate variables called:

```text
environment
app
managed_by
```

because those are keys inside the `labels` map.

## Matching Summary

```text
terraform.tfvars key
    must match
live variables.tf variable name

live main.tf right side var.xxx
    must match
live variables.tf variable name

live main.tf left side argument
    must match
module variables.tf variable name

module main.tf var.xxx
    must match
module variables.tf variable name
```

Example:

```hcl
name = var.name
```

means:

```text
left side "name"  -> must exist in modules/gcp-vm/variables.tf
right side var.name -> must exist in live/.../variables.tf
```
