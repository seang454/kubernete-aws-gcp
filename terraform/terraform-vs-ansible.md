# Terraform vs Ansible

This note explains the difference between Terraform and Ansible, why Terraform is usually better for infrastructure, and why Ansible is better for server configuration.

## Short Summary

```text
Terraform = create and manage infrastructure
Ansible   = configure servers and applications
```

For your SonarQube project:

```text
Terraform:
  create GCP VM
  create firewall rules
  output server IP

Ansible:
  SSH to VM
  install Java
  install PostgreSQL
  install SonarQube
  configure systemd
  start SonarQube
```

## What Terraform Is Used For

Terraform is an Infrastructure as Code tool.

It is best for managing cloud infrastructure resources such as:

- Virtual machines
- Networks
- Subnets
- Firewall rules
- Load balancers
- Databases
- DNS records
- IAM permissions
- Kubernetes clusters
- Storage buckets

Example Terraform resource:

```hcl
resource "google_compute_instance" "sonarqube" {
  name         = "sonarqube-vm"
  machine_type = "e2-standard-2"
  zone         = "asia-southeast1-a"
}
```

This means:

```text
Create a GCP VM named sonarqube-vm.
```

## What Ansible Is Used For

Ansible is a configuration management and automation tool.

It is best for configuring what is inside a server:

- Install packages
- Create Linux users
- Copy files
- Edit config files
- Start services
- Restart applications
- Install Docker
- Install SonarQube
- Configure PostgreSQL

Example Ansible task:

```yaml
- name: Install Java
  ansible.builtin.apt:
    name: openjdk-17-jdk
    state: present
```

This means:

```text
SSH to the server and make sure Java is installed.
```

## Main Difference

| Topic | Terraform | Ansible |
| --- | --- | --- |
| Main purpose | Infrastructure provisioning | Server configuration |
| Best for | Cloud resources | OS and app setup |
| Style | Declarative | Task-based |
| State file | Yes | Usually no |
| Preview changes | Strong with `terraform plan` | Limited compared to Terraform |
| Destroy resources | Strong with `terraform destroy` | Not its main purpose |
| Server package setup | Possible, but not ideal | Very strong |
| Cloud resource lifecycle | Very strong | Possible, but not ideal |

## Why Terraform Is Better for Infrastructure

### 1. Terraform Has State

Terraform keeps a state file.

The state file records what Terraform created.

Example:

```text
VM ID
firewall rule ID
public IP
network name
database ID
outputs
```

Because of state, Terraform knows:

```text
This VM already exists.
This firewall rule already exists.
This resource belongs to this Terraform project.
```

Ansible can create cloud resources, but it does not manage long-term infrastructure state as strongly as Terraform.

## 2. Terraform Can Plan Before Apply

Terraform can show what will happen before it changes anything:

```bash
terraform plan
```

Example:

```text
+ create GCP VM
+ create firewall rule
~ update machine type
- destroy old IP address
```

This is very useful because you can review infrastructure changes before applying them.

Ansible usually runs tasks directly. It can show changed/ok status, but it does not provide the same infrastructure lifecycle preview as Terraform.

## 3. Terraform Understands Dependencies

Terraform builds a dependency graph.

Example:

```text
network -> firewall -> VM -> output IP
```

Terraform knows the correct order:

```text
Create network first.
Create firewall rule.
Create VM.
Output VM IP.
```

You do not need to manually write every step in order if resources reference each other.

## 4. Terraform Is Better at Destroying Infrastructure

Terraform can destroy resources it manages:

```bash
terraform destroy
```

Terraform uses state to know exactly what to delete.

Example:

```text
delete VM
delete firewall rule
delete static IP
delete database
```

Ansible can delete cloud resources too, but Terraform is designed for this full infrastructure lifecycle.

## 5. Terraform Is Declarative

Terraform describes the final desired infrastructure state.

Example:

```hcl
resource "google_compute_instance" "sonarqube" {
  name         = "sonarqube-vm"
  machine_type = "e2-standard-2"
}
```

Meaning:

```text
I want this VM to exist.
```

Terraform decides whether it needs to create, update, or replace the VM.

Ansible is usually more task-based:

```text
Do this step.
Then this step.
Then this step.
```

## Why Ansible Is Better for Server Configuration

Terraform can run shell commands, but it is not the best tool for managing inside a server.

Server configuration includes:

```text
install Java
install PostgreSQL
create Linux users
write sonar.properties
configure systemd
start SonarQube
restart service when config changes
```

Ansible has modules for these tasks:

```yaml
ansible.builtin.apt
ansible.builtin.user
ansible.builtin.template
ansible.builtin.systemd
community.postgresql.postgresql_db
```

Ansible can check the server and apply only what is missing or changed.

## Can Ansible Do Infrastructure Too?

Yes, Ansible can create cloud infrastructure.

But Terraform is usually preferred for infrastructure because Terraform has:

- Better state management
- Better planning
- Better dependency graph
- Better destroy workflow
- Strong cloud provider ecosystem
- Cleaner infrastructure lifecycle management

So the best practice is often:

```text
Terraform for infrastructure
Ansible for configuration
```

## Can Terraform Configure Servers Too?

Yes, Terraform can run scripts using provisioners.

Example:

```hcl
provisioner "remote-exec" {
  inline = [
    "sudo apt update",
    "sudo apt install -y openjdk-17-jdk"
  ]
}
```

But this is not ideal because:

- Terraform does not track every package.
- Terraform does not track every config file line.
- Re-running scripts can be messy.
- `terraform destroy` does not always undo server configuration.
- If someone removes Java manually, Terraform may not notice.

Ansible is much better for that job.

## Best Architecture

Use Terraform and Ansible together.

```text
Terraform
  -> creates infrastructure
  -> outputs server IP

Ansible
  -> uses server IP
  -> configures the server
```

Flow:

```text
terraform apply
      |
      v
GCP VM created
      |
      v
terraform output -raw server_ip
      |
      v
Ansible inventory
      |
      v
ansible-playbook
      |
      v
SonarQube installed and running
```

## Your Project Structure

In your project:

```text
terraform/
|-- infrastructure/
|   |-- modules/
|   |   |-- gcp-vm/
|   |-- live/
|       |-- dev/
|           |-- asia-southeast1/
|               |-- gcp-vm/
|
|-- ansible/
|   |-- inventories/
|   |-- playbooks/
|   |-- roles/
|       |-- sonarqube/
```

Meaning:

```text
terraform/infrastructure = Terraform code for GCP VM and firewall
terraform/ansible        = Ansible code for SonarQube installation
```

## Command Flow

Step 1: Create infrastructure with Terraform.

```powershell
cd D:\CSTADPreUniversityTraining\ITP\researchforinterview\terraform\infrastructure\live\dev\asia-southeast1\gcp-vm
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
terraform output -raw server_ip
```

Step 2: Put the IP in Ansible inventory.

```text
terraform/ansible/inventories/dev/hosts.ini
```

Step 3: Configure the server with Ansible.

```bash
cd terraform/ansible
ansible-galaxy collection install -r collections/requirements.yml
ansible-playbook -i inventories/dev/hosts.ini playbooks/sonarqube.yml
```

## Simple Analogy

Think of building a house:

```text
Terraform builds the house.
Ansible installs furniture, lights, appliances, and settings.
```

For cloud infrastructure:

```text
Terraform creates the VM, firewall, network, and database.
Ansible installs software inside the VM.
```

## Final Recommendation

Use Terraform for:

```text
GCP VM
firewall rules
database
network
IAM
outputs
```

Use Ansible for:

```text
Java
PostgreSQL setup
SonarQube installation
sonar.properties
systemd service
service restart
```

Short final answer:

```text
Terraform is better for infrastructure lifecycle.
Ansible is better for server configuration.
Together, they are stronger than either one alone.
```

