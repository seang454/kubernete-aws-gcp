# Infrastructure Example: GCP VM for SonarQube

This folder contains the Terraform part of the project.

Terraform is now responsible for infrastructure only:

```text
create GCP VM
create firewall rules
create Cloudflare DNS records
output server IP
```

Ansible is responsible for server configuration:

```text
install Java
install PostgreSQL
install SonarQube
configure systemd
start SonarQube
```

## Structure

```text
infrastructure/
|-- README.md
|-- .gitignore
|
|-- .github/
|   |-- workflows/
|       |-- terraform-plan.yml
|       |-- terraform-apply.yml
|
|-- modules/
|   |-- gcp-vm/
|   |   |-- main.tf
|   |   |-- variables.tf
|   |   |-- outputs.tf
|   |   |-- versions.tf
|   |   |-- README.md
|   |
|   |-- cloudflare-dns/
|       |-- main.tf
|       |-- variables.tf
|       |-- outputs.tf
|       |-- versions.tf
|       |-- README.md
|
|-- live/
|   |-- dev/
|       |-- asia-southeast1/
|           |-- gcp-vm/
|               |-- backend.tf
|               |-- providers.tf
|               |-- gcp_vm.tf
|               |-- cloudflare_dns.tf
|               |-- ansible_inventory.tf
|               |-- variables.tf
|               |-- outputs.tf
|               |-- terraform.tfvars.example
|               |-- README.md
|
|-- scripts/
|   |-- check-format.sh
|   |-- validate-all.sh
|   |-- plan-all.sh
|   |-- apply-dev-and-run-ansible.sh
|
|-- docs/
|   |-- architecture.md
|   |-- runbook.md
|   |-- disaster-recovery.md
|
|-- state/
|   |-- dev/
|       |-- asia-southeast1/
```

## Main Folders

`modules/gcp-vm` is the reusable Terraform module that creates a GCP VM and firewall rules.

`modules/cloudflare-dns` is the reusable Terraform module that creates Cloudflare DNS records for service subdomains.

`live/dev/asia-southeast1/gcp-vm` is the real dev deployment. Run Terraform from this folder.

`state/` stores local Terraform state for this learning project. For production, use a remote backend such as GCS or HCP Terraform.

`../ansible_service_config` contains the Ansible configuration that installs and configures SonarQube after the VM exists.

## Run Terraform

PowerShell:

```powershell
cd D:\CSTADPreUniversityTraining\ITP\researchforinterview\terraform\infrastructure\live\dev\asia-southeast1\gcp-vm
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
terraform init
terraform plan
terraform apply
terraform output ansible_inventory_path
```

Terraform writes the VM external IP into:

```text
terraform/ansible_service_config/inventories/dev/hosts.ini
```

Then run Ansible from Linux or WSL:

```bash
cd terraform/ansible_service_config
ansible-galaxy collection install -r collections/requirements.yml
ansible-playbook -i inventories/dev/hosts.ini playbooks/sonarqube.yml
```

## One Command Flow

Use this wrapper when you want Terraform to finish first, then choose whether to continue with Ansible.

```bash
cd terraform/infrastructure
bash scripts/apply-dev-and-run-ansible.sh
```

The script runs:

```text
terraform init
terraform apply
prompt: Run Ansible now?
ansible-playbook -i inventories/dev/hosts.ini playbooks/site.yml
```

To run a specific playbook after Terraform:

```bash
bash scripts/apply-dev-and-run-ansible.sh playbooks/sonarqube.yml
```

## Flow

```text
terraform/infrastructure/live/dev/asia-southeast1/gcp-vm
  -> creates GCP VM
  -> creates firewall rules
  -> gets VM external IP
  -> creates Cloudflare DNS records when enabled
  -> writes Ansible inventory

terraform/ansible_service_config
  -> uses inventories/dev/hosts.ini
  -> installs and configures SonarQube
```

## Important

The previous Terraform shell-script installer approach has been removed.

The current design is:

```text
Terraform = infrastructure
Ansible   = server configuration
```
