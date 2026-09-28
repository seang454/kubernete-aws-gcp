# Dev GCP VM for SonarQube

This Terraform root module creates one or more GCP VMs for SonarQube.

Terraform creates the VMs and firewall rules. Ansible configures SonarQube on the VMs.

## Create Many VMs

Set the number of machines in `terraform.tfvars`:

```hcl
instance_count = 3
```

Set the zones Terraform can use:

```hcl
zones = [
  "asia-southeast1-a",
  "asia-southeast1-b",
  "asia-southeast1-c"
]
```

Terraform spreads VMs across the zones in order:

```text
gcp-vm-1 -> asia-southeast1-a
gcp-vm-2 -> asia-southeast1-b
gcp-vm-3 -> asia-southeast1-c
gcp-vm-4 -> asia-southeast1-a
```

The default is `instance_count = 1` so Terraform does not create extra paid VMs by accident.

## Dynamic UP Zone Discovery

Use this in `terraform.tfvars`:

```hcl
auto_discover_up_zones = true

fallback_regions = [
  "asia-east1",
  "asia-northeast1"
]
```

Terraform asks GCP for zones with status `UP`, then builds the VM plan from:

```text
1. Preferred zones from zones, but only if GCP reports them as UP
2. Other UP zones in the same regions
3. UP zones from fallback_regions
```

## Handle Failed Zones Or Regions

Terraform cannot catch `ZONE_RESOURCE_POOL_EXHAUSTED` and retry another zone inside the same `terraform apply`. If GCP fails in a zone or region, update `terraform.tfvars` and rerun Terraform.

```hcl
blocked_zones = [
  "asia-southeast1-a"
]

blocked_regions = [
  "asia-southeast1"
]
```

If you block a whole region, add zones from another region to `zones` so Terraform has somewhere else to create the VM.

More detail is in:

```text
terraform/infrastructure/docs/gcp-vm-error-handling.md
```

## Keep Terraform VMs Running

Use this in `terraform.tfvars`:

```hcl
desired_status = "RUNNING"
```

This is the Terraform version of starting a stopped VM, but only for VMs already managed in Terraform state.

## Choose Machine Type Per VM

Use `machine_types` to choose the VM size by index.

```hcl
instance_count = 3

machine_types = [
  "e2-standard-2", # gcp-vm-1
  "e2-standard-4", # gcp-vm-2
  "e2-medium"      # gcp-vm-3 and later VMs
]
```

Terraform matches the VM to the list by index:

```text
VM 1 -> machine_types[0]
VM 2 -> machine_types[1]
VM 3 -> machine_types[2]
```

If there are more VMs than `machine_types` values, Terraform reuses the last value.

```text
1 machine type  -> all VMs use machine_types[0]
2 machine types -> VM 1 uses machine_types[0], VM 2 and later use machine_types[1]
3 machine types -> VM 1 uses machine_types[0], VM 2 uses machine_types[1], VM 3 and later use machine_types[2]
```

## Run Terraform

Authenticate to GCP with Application Default Credentials:

```powershell
gcloud auth application-default login
gcloud config set project YOUR_GCP_PROJECT_ID
```

By default, Terraform can automatically use the ADC file created by `gcloud`.

Recommended portable configuration:

```hcl
gcp_adc_file = ""
```

With the empty value, the Google provider automatically selects the ADC
credentials belonging to whichever Linux, WSL, Windows, or CI user runs
Terraform. You do not need to write `/home/seang`, `/home/ubuntu`, or another
username in Terraform.

If you deliberately want to select the standard Linux/WSL ADC file explicitly,
use `~`; Terraform expands it to the current user's home directory:

```hcl
gcp_adc_file = "~/.config/gcloud/application_default_credentials.json"
```

On Windows, the default ADC file is usually similar to:

```text
C:/Users/M/AppData/Roaming/gcloud/application_default_credentials.json
```

If you want to explicitly configure the ADC file, set this in `terraform.tfvars`:

```hcl
gcp_adc_file = "C:/Users/M/AppData/Roaming/gcloud/application_default_credentials.json"
```

For HTTPS with Certbot, the VM must allow public HTTP and HTTPS traffic:

```hcl
public_service_ports         = [80, 443]
public_service_source_ranges = ["0.0.0.0/0"]
```

Your DNS records, for example `sonarqube.your-domain.com`, must point to the VM external IP before Ansible runs Certbot.

For production, also restrict direct application ports such as `9000` so users enter through HTTPS/Nginx instead of bypassing the proxy.

## Cloudflare DNS

Terraform can create Cloudflare DNS records after it creates the VM static IPs.

Use the Cloudflare API token from your shell when possible:

```powershell
$env:CLOUDFLARE_API_TOKEN = "YOUR_CLOUDFLARE_API_TOKEN"
```

The token should be able to edit DNS records in the Cloudflare zone.

Then enable DNS in `terraform.tfvars`:

```hcl
enable_cloudflare_dns = true
cloudflare_zone_id    = "YOUR_CLOUDFLARE_ZONE_ID"
```

Map each hostname to the VM index that should receive traffic:

```hcl
cloudflare_dns_records = {
  defectdojo = {
    hostname = "defectdojo.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
  }

  jenkins = {
    hostname = "jenkins.seang.shop"
    type     = "A"
    vm_index = 1
    proxied  = false
  }

  nexus = {
    hostname = "nexus.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
  }

  nexus_docker = {
    hostname = "docker.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
  }

  sonarqube = {
    hostname = "sonarqube.seang.shop"
    type     = "A"
    vm_index = 1
    proxied  = false
  }

  trivy = {
    hostname = "trivy.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
  }

  vault = {
    hostname = "vault.seang.shop"
    type     = "A"
    vm_index = 2
    proxied  = false
  }

  defectdojo_alias = {
    hostname = "dojo.seang.shop"
    type     = "CNAME"
    content  = "defectdojo.seang.shop"
    proxied  = false
  }

  jenkins_alias = {
    hostname = "ci.seang.shop"
    type     = "CNAME"
    content  = "jenkins.seang.shop"
    proxied  = false
  }

  nexus_alias = {
    hostname = "repo.seang.shop"
    type     = "CNAME"
    content  = "nexus.seang.shop"
    proxied  = false
  }

  nexus_docker_alias = {
    hostname = "registry.seang.shop"
    type     = "CNAME"
    content  = "docker.seang.shop"
    proxied  = false
  }

  sonarqube_alias = {
    hostname = "quality.seang.shop"
    type     = "CNAME"
    content  = "sonarqube.seang.shop"
    proxied  = false
  }

  trivy_alias = {
    hostname = "scanner.seang.shop"
    type     = "CNAME"
    content  = "trivy.seang.shop"
    proxied  = false
  }

  vault_alias = {
    hostname = "secrets.seang.shop"
    type     = "CNAME"
    content  = "vault.seang.shop"
    proxied  = false
  }
}
```

`vm_index` is one-based:

```text
vm_index = 1 -> gcp-vm-1 external IP
vm_index = 2 -> gcp-vm-2 external IP
```

You can also point a record to a manually specified IP:

```hcl
external_service = {
  hostname = "external.seang.shop"
  type     = "A"
  content  = "203.0.113.10"
  proxied  = false
}
```

For a CNAME, set `type = "CNAME"` and use `content` as the target hostname:

```hcl
ci = {
  hostname = "ci.seang.shop"
  type     = "CNAME"
  content  = "jenkins.seang.shop"
  proxied  = false
}
```

Keep `proxied = false` while Ansible uses Certbot HTTP validation.

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
terraform init -reconfigure -backend-config=backend.gcs.hcl
terraform plan
terraform apply
terraform output -raw server_ip
terraform output cloudflare_hostnames
terraform output cloudflare_dns_records
```

For multiple VMs, get all public IP addresses:

```powershell
terraform output discovery_regions
terraform output discovered_up_zones
terraform output candidate_zones
terraform output machine_plan
terraform output server_ips
terraform output static_ips
terraform output instances
```

## Generated Ansible Inventory

After `terraform apply`, Terraform writes the VM external IPs into the Ansible inventory:

```text
terraform/ansible_service_config/inventories/dev/hosts.ini
```

The inventory layout is rendered from:

```text
templates/ansible_inventory.tftpl
```

Terraform passes the computed groups and host lines into `templatefile()`, then `local_file` writes the generated inventory.

The generated file looks like this:

```ini
# Generated by Terraform. Do not edit manually.
# Source: terraform/infrastructure/live/dev/asia-southeast1/gcp-vm

[sonarqube]
gcp-vm-1 ansible_host=34.124.10.20 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

For many VMs, Terraform writes one host line per VM:

```ini
[sonarqube]
gcp-vm-1 ansible_host=34.124.10.20 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
gcp-vm-2 ansible_host=34.124.10.21 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Control the inventory output with these values in `terraform.tfvars`:

```hcl
ansible_inventory_path       = "../../../../../ansible_service_config/inventories/dev/hosts.ini"
ansible_ssh_private_key_path = "~/.ssh/id_rsa"
```

The best design for this project is dynamic service-to-VM mapping.

When `enable_cloudflare_dns = true`, Terraform derives Ansible inventory groups from `cloudflare_dns_records`:

```hcl
cloudflare_dns_records = {
  sonarqube = {
    hostname = "sonarqube.seang.shop"
    type     = "A"
    vm_index = 1
  }

  nexus = {
    hostname = "nexus.seang.shop"
    type     = "A"
    vm_index = 2
  }
}
```

Terraform writes this inventory:

```ini
[nexus]
gcp-vm-2 ansible_host=... ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[sonarqube]
gcp-vm-1 ansible_host=... ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

If a DNS record should not create an Ansible group, disable it:

```hcl
nexus_docker = {
  hostname             = "docker.seang.shop"
  type                 = "A"
  vm_index             = 2
  create_ansible_group = false
}
```

If you want dynamic inventory before enabling Cloudflare DNS, use `ansible_service_targets`:

```hcl
ansible_service_targets = {
  sonarqube = { vm_index = 1 }
  jenkins   = { vm_index = 1 }
  nexus     = { vm_index = 2 }
}
```

If both `ansible_service_targets` and Cloudflare-derived targets are empty, Terraform falls back to `ansible_inventory_groups` and puts all VMs under every listed group.

If the same Terraform-created VM should be configured by multiple Ansible service roles, map multiple groups to the same `vm_index`:

```hcl
ansible_service_targets = {
  sonarqube = { vm_index = 1 }
  jenkins   = { vm_index = 1 }
  trivy     = { vm_index = 1 }
}
```

Then run:

```bash
cd terraform/ansible_service_config
ansible-galaxy collection install -r collections/requirements.yml
ansible-playbook -i inventories/dev/hosts.ini playbooks/sonarqube.yml
```

## Generated Ansible Domain Variables

After Cloudflare DNS is enabled and created, Terraform also writes service domain values into Ansible group vars:

```text
terraform/ansible_service_config/group_vars/sonarqube/terraform_domains.yml
terraform/ansible_service_config/group_vars/jenkins/terraform_domains.yml
terraform/ansible_service_config/group_vars/nexus/terraform_domains.yml
terraform/ansible_service_config/group_vars/defectdojo/terraform_domains.yml
terraform/ansible_service_config/group_vars/trivy/terraform_domains.yml
terraform/ansible_service_config/group_vars/vault/terraform_domains.yml
```

The generated domain variable file layout is rendered from:

```text
templates/ansible_group_vars_domains.tftpl
```

Example generated file:

```yaml
---
# Generated by Terraform. Do not edit manually.
# Source: terraform/infrastructure/live/dev/asia-southeast1/gcp-vm/ansible_group_vars.tf
service_domain: "sonarqube.seang.shop"
service_hostname: "sonarqube.seang.shop"
sonarqube_domain: "sonarqube.seang.shop"
```

This lets Terraform create the DNS record in Cloudflare first, then pass the finished domain name to Ansible. Ansible loads `group_vars/<group>/terraform_domains.yml` automatically when the inventory contains a matching group such as `[sonarqube]`.

For existing roles, Terraform writes the variable names the role already expects, such as `sonarqube_domain` or `jenkins_domain`. For new roles, prefer using the generic `service_domain` variable so a new Cloudflare A/AAAA record can create the inventory group and domain variable without adding another Terraform mapping.

Keep secrets and non-DNS settings in your normal Ansible files, for example:

```text
terraform/ansible_service_config/group_vars/sonarqube.yml
terraform/ansible_service_config/group_vars/sonarqube/secrets.yml
```

Do not manually edit `terraform_domains.yml`; it is generated and ignored by Git.

Terraform uses the `local_file` resource for these generated files:

```text
File does not exist -> Terraform creates it
File already exists -> Terraform updates it when the domain value changes
```

Because Terraform owns the full generated file, keep manual settings and secrets in separate Ansible files instead of `terraform_domains.yml`.
