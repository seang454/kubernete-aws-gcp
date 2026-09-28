# Architecture Notes

This document explains the current Terraform + Ansible architecture.

The previous Terraform shell-script installer approach has been removed.

Current responsibility split:

```text
Terraform = create GCP infrastructure and Cloudflare DNS records
Ansible   = configure the VM and install SonarQube
```

## VS Code Folder Explanation

```text
terraform/
|-- ansible_service_config/
|   |-- inventories/
|   |-- group_vars/
|   |-- collections/
|   |-- playbooks/
|   |-- roles/
|   |-- ansible.cfg
|   |-- README.md
|
|-- infrastructure/
|   |-- .github/
|   |-- docs/
|   |-- live/
|   |-- modules/
|   |-- scripts/
|   |-- state/
|   |-- .gitignore
|   |-- README.md
|
|-- infrastructure-sample/
|-- Terraform syntax complete.md
|-- terraform-installation.md
|-- terraform-reference-architecture.md
|-- terraform-summary.md
|-- terraformCLI-command.md
|-- module-vs-live-files.md
```

## `terraform/ansible_service_config/`

This folder configures the server after Terraform creates the GCP VM.

It contains:

```text
inventories/   server IPs for dev, staging, prod
group_vars/    shared Ansible variables
collections/   Ansible collection dependencies
playbooks/     playbooks to run
roles/         reusable Ansible roles
ansible.cfg    Ansible project config
README.md      run instructions
```

The important role is:

```text
terraform/ansible_service_config/roles/sonarqube
```

That role installs and configures SonarQube on the VM.

## `terraform/infrastructure/`

This folder contains Terraform code.

Terraform creates the GCP VM and firewall rules, then writes the VM IP address into the Ansible inventory.

You do not run Terraform directly from this folder. Run Terraform from a root module under `live/`.

## `terraform/infrastructure/modules/`

This folder contains reusable Terraform modules.

Current module:

```text
modules/gcp-vm
modules/cloudflare-dns
```

The `gcp-vm` module creates:

- GCP VM instance
- SSH firewall rule
- SonarQube port `9000` firewall rule
- HTTP/HTTPS firewall rule for Nginx and Certbot
- Public IP output for Ansible

The `cloudflare-dns` module creates:

- Cloudflare `A` records for service subdomains
- One or many DNS names pointing to the same VM external IP
- Different DNS names pointing to different VM indexes

## `terraform/infrastructure/live/`

This folder contains real Terraform deployments.

Current dev deployment:

```text
live/dev/asia-southeast1/gcp-vm
```

Run Terraform from this folder:

```powershell
cd D:\CSTADPreUniversityTraining\ITP\researchforinterview\terraform\infrastructure\live\dev\asia-southeast1\gcp-vm
terraform init
terraform plan
terraform apply
```

## `terraform/infrastructure/live/dev/asia-southeast1/gcp-vm/`

This is the dev GCP VM Terraform root module.

It contains:

```text
backend.tf
providers.tf
gcp_vm.tf
cloudflare_dns.tf
ansible_inventory.tf
ansible_group_vars.tf
templates/ansible_inventory.tftpl
templates/ansible_group_vars_domains.tftpl
variables.tf
outputs.tf
terraform.tfvars.example
README.md
```

File purposes:

| File | Purpose |
| --- | --- |
| `backend.tf` | Defines where Terraform state is stored. |
| `providers.tf` | Configures the Google, Cloudflare, and local providers. |
| `gcp_vm.tf` | Calls the reusable `modules/gcp-vm` module. |
| `cloudflare_dns.tf` | Converts service hostnames to Cloudflare DNS records. |
| `ansible_inventory.tf` | Passes Terraform-created VM IPs into the inventory template and writes the Ansible inventory file. |
| `ansible_group_vars.tf` | Passes Cloudflare domain values into the group vars template and writes generated `terraform_domains.yml` files. |
| `templates/ansible_inventory.tftpl` | Template for the generated Ansible inventory file. |
| `templates/ansible_group_vars_domains.tftpl` | Template for generated domain-only Ansible group vars files. |
| `variables.tf` | Defines inputs for this dev deployment. |
| `outputs.tf` | Outputs values such as `server_ip`, `server_ips`, and `ansible_inventory_path`. |
| `terraform.tfvars.example` | Example values. Copy to `terraform.tfvars`. |
| `README.md` | Run instructions for this deployment. |

## `terraform/infrastructure/scripts/`

This folder contains helper scripts:

```text
check-format.sh
validate-all.sh
plan-all.sh
```

They help format, validate, and plan the current Terraform root modules.

## `terraform/infrastructure/state/`

This folder stores local Terraform state files for this learning project.

Example:

```text
state/dev/asia-southeast1/gcp-vm.tfstate
```

For production, use remote state such as:

- GCS backend
- HCP Terraform
- S3 backend

## Current Run Flow

Step 1: Terraform creates the VM.

```powershell
cd D:\CSTADPreUniversityTraining\ITP\researchforinterview\terraform\infrastructure\live\dev\asia-southeast1\gcp-vm
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
terraform output ansible_inventory_path
```

Step 2: Terraform writes the IP into Ansible inventory.

```text
terraform/ansible_service_config/inventories/dev/hosts.ini
```

Step 3: Ansible configures the server.

```bash
cd terraform/ansible_service_config
ansible-galaxy collection install -r collections/requirements.yml
ansible-playbook -i inventories/dev/hosts.ini playbooks/sonarqube.yml
```

## Flow Diagram

```text
Terraform root module
live/dev/asia-southeast1/gcp-vm
        |
        v
Reusable Terraform module
modules/gcp-vm
        |
        v
GCP VM + firewall rules
        |
        v
VM external IP values
        |
        v
Cloudflare DNS records
        |
        v
Generated Ansible inventory
terraform/ansible_service_config/inventories/dev/hosts.ini
        |
        v
Ansible role
roles/sonarqube
        |
        v
SonarQube installed and running
```

## Short Summary

```text
terraform/infrastructure/modules/gcp-vm = reusable VM infrastructure code
terraform/infrastructure/live/...      = real GCP VM deployment
terraform/ansible_service_config/roles/sonarqube = server configuration
terraform/ansible_service_config/inventories/    = server IPs for Ansible
```
