# Kubespray Runbook

## Apply Infrastructure

```bash
cd terraform/k8s_infrastructure/live/dev/asia-southeast1/kubespray-k8s
terraform init
terraform apply
```

## Check Generated Inventory

```bash
terraform output kubespray_inventory_path
cat ../../../../../ansible_kubespray_k8s/kubespray/inventory/sample/inventory.ini
```

## Run Kubespray

```bash
cd terraform/ansible_kubespray_k8s/kubespray
ansible-playbook -i inventory/sample/inventory.ini cluster.yml
```

## Verify SSH

```bash
ansible -i inventory/sample/inventory.ini all -m ping
```

## Useful Outputs

```bash
terraform output control_plane_nodes
terraform output worker_nodes
terraform output all_nodes
```
