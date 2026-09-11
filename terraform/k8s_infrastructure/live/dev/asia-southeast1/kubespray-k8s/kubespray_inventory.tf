resource "local_file" "kubespray_inventory" {
  filename = abspath("${path.module}/${var.kubespray_inventory_path}")

  content = templatefile("${path.module}/templates/kubespray_inventory.tftpl", {
    control_plane_nodes          = module.kubespray_cluster.control_plane_nodes
    worker_nodes                 = module.kubespray_cluster.worker_nodes
    ansible_user                 = trimspace(var.ansible_user) != "" ? var.ansible_user : var.ssh_user
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
    ansible_python_interpreter   = var.ansible_python_interpreter
    ansible_ssh_extra_args       = var.ansible_ssh_extra_args
  })
}

# Generate the ansible_kubespray_k8s/inventory.ini used by the Ansible playbooks
# (zsh setup, pre-flight checks, etc.) that run directly on the cluster nodes.
# This uses Kubespray-standard group names (kube_control_plane / kube_node) so
# both inventories stay consistent and interchangeable.
resource "local_file" "ansible_inventory" {
  filename = abspath("${path.module}/${var.ansible_inventory_path}")

  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    control_plane_nodes          = module.kubespray_cluster.control_plane_nodes
    worker_nodes                 = module.kubespray_cluster.worker_nodes
    ansible_user                 = trimspace(var.ansible_user) != "" ? var.ansible_user : var.ssh_user
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
    ansible_python_interpreter   = var.ansible_python_interpreter
    ansible_ssh_extra_args       = var.ansible_ssh_extra_args
  })
}

# Generate the ansible-nfs-cluster-genesha/inventory/hosts.ini used by Ansible
# to deploy Ceph, NFS-Ganesha, and Pacemaker/Corosync across the storage nodes.
resource "local_file" "nfs_inventory" {
  filename = abspath("${path.module}/${var.nfs_inventory_path}")

  content = templatefile("${path.module}/templates/nfs_inventory.tftpl", {
    nfs_nodes                    = module.kubespray_cluster.nfs_nodes
    control_plane_nodes          = module.kubespray_cluster.control_plane_nodes
    worker_nodes                 = module.kubespray_cluster.worker_nodes
    ansible_user                 = trimspace(var.ansible_user) != "" ? var.ansible_user : var.ssh_user
    ansible_ssh_private_key_file = pathexpand(var.ansible_ssh_private_key_file)
    ansible_python_interpreter   = var.ansible_python_interpreter
    ansible_ssh_extra_args       = var.ansible_ssh_extra_args
  })
}
