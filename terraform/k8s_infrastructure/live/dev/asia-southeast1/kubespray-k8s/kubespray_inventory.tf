locals {
  all_control_plane_nodes = concat(
    module.gcp_kubespray_cluster.control_plane_nodes,
    module.aws_kubespray_workers.control_plane_nodes
  )

  all_worker_nodes = concat(
    module.gcp_kubespray_cluster.worker_nodes,
    module.aws_kubespray_workers.worker_nodes
  )

  # When exclude_stopped_nodes_from_inventory is true, filter out stopped nodes
  # so playbooks do not time out attempting SSH connections to powered-off VMs.
  active_inventory_control_planes = var.exclude_stopped_nodes_from_inventory ? [
    for node in local.all_control_plane_nodes : node
    if !contains(var.stop_nodes, node.instance_name)
  ] : local.all_control_plane_nodes

  active_inventory_workers = var.exclude_stopped_nodes_from_inventory ? [
    for node in local.all_worker_nodes : node
    if !contains(var.stop_nodes, node.instance_name)
  ] : local.all_worker_nodes
}

# Generate the Kubespray inventory used by Kubespray cluster.yml
resource "local_file" "kubespray_inventory" {
  filename = abspath("${path.module}/${var.kubespray_inventory_path}")

  content = templatefile("${path.module}/templates/kubespray_inventory.tftpl", {
    control_plane_nodes          = local.active_inventory_control_planes
    worker_nodes                 = local.active_inventory_workers
    use_wireguard_ip             = var.use_wireguard_ip
    use_public_access_ip         = var.use_public_access_ip
    ansible_user                 = trimspace(var.ansible_user) != "" ? var.ansible_user : var.ssh_user
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
    ansible_python_interpreter   = var.ansible_python_interpreter
    ansible_ssh_extra_args       = var.ansible_ssh_extra_args
  })
}

# Generate the ansible_kubespray_k8s/inventory.ini used by Ansible playbooks
# (zsh setup, pre-flight checks, etc.) that run directly on the cluster nodes.
resource "local_file" "ansible_inventory" {
  filename = abspath("${path.module}/${var.ansible_inventory_path}")

  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    control_plane_nodes          = local.active_inventory_control_planes
    worker_nodes                 = local.active_inventory_workers
    use_wireguard_ip             = var.use_wireguard_ip
    ansible_user                 = trimspace(var.ansible_user) != "" ? var.ansible_user : var.ssh_user
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
    ansible_python_interpreter   = var.ansible_python_interpreter
    ansible_ssh_extra_args       = var.ansible_ssh_extra_args
  })
}

# Generate the WireGuard Full Mesh inventory in wiregurad/inventory/hosts.ini
resource "local_file" "wireguard_inventory" {
  filename = abspath("${path.module}/${var.wireguard_inventory_path}")

  content = templatefile("${path.module}/templates/wireguard_inventory.tftpl", {
    control_plane_nodes          = local.active_inventory_control_planes
    worker_nodes                 = local.active_inventory_workers
    ansible_user                 = trimspace(var.ansible_user) != "" ? var.ansible_user : var.ssh_user
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
    ansible_python_interpreter   = var.ansible_python_interpreter
    ansible_ssh_extra_args       = var.ansible_ssh_extra_args
  })
}
