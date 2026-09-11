# Kubernetes Infrastructure

This Terraform project creates GCP VMs for Kubespray and generates the Kubespray inventory with the real VM IP addresses.

## Flow

```text
terraform.tfvars
  -> choose master/control-plane count and worker count
  -> choose machine types, zones, SSH user/key

Terraform
  -> creates GCP control plane VMs
  -> creates GCP worker VMs
  -> reserves external IPs
  -> reads internal IPs
  -> writes Kubespray inventory.ini

Kubespray
  -> reads inventory.ini
  -> installs Kubernetes with Ansible
```

## Main Root

```text
terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s
```

## Main Module

```text
terraform/k8s_infrastructure/modules/gcp-kubespray-cluster
```

## Generated Inventory

```text
terraform/ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini
```

Terraform updates this file during `terraform apply`.

## Run

```bash
cd terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s
terraform init
terraform apply
```

Then run Kubespray:

```bash
cd terraform/ansible_kubespray_k8s/kubespray
ansible-playbook -i inventory/sample/inventory.ini cluster.yml
```

## Stop or Start Machines

To stop (power off) created VMs without deleting them:
```bash
./scripts/stop-machines.sh
# OR: terraform -chdir="live/dev/asia-southeast1/kubespray-k8s" apply -var="desired_status=TERMINATED"
```

To start machines back up:
```bash
./scripts/start-machines.sh
# OR: terraform -chdir="live/dev/asia-southeast1/kubespray-k8s" apply -var="desired_status=RUNNING"
```

