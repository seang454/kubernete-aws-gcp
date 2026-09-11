# 📊 Production Observability Ansible Project (`observ-monitory`)

This Ansible project automates the deployment, verification, and teardown of the end-to-end monitoring architecture defined in the [Observability Architecture Guide](file:///home/seang/nfs-cluster/observ-monitory/observability-architecture-guide.md) for **HA Ceph + NFS-Ganesha + Kubernetes Storage Infrastructure**.

---

## 📁 Directory Structure

```text
observ-monitory/
├── ansible.cfg                    # Ansible default options
├── inventory.ini                  # IDC / GCP Host Node inventory mapping
├── site.yml                       # Deploy playbook executing all 3 phases
├── verify.yml                     # Automated health verification playbook
├── uninstall.yml                  # Teardown playbook wiping monitoring & freeing resources
├── group_vars/
│   └── all.yml                    # Global ports, domains, storage classes, & VIP vars
├── roles/
│   ├── ceph_observability/        # Enables Ceph mgr prometheus plugin (Port 9283)
│   ├── host_observability/        # Installs node_exporter (Port 9100) & Grafana Alloy
│   └── k8s_observability/         # Installs Prometheus & Loki stack (Decoupled storage)
└── observability-architecture-guide.md
```

---

## 🚀 Execution Instructions

### 1. Deploy Monitoring Stack
To deploy Prometheus, Loki, Grafana, Exporters, and Alloy:
```bash
cd observ-monitory
ansible-playbook -i inventory.ini site.yml
```

### 2. Verify System Health & Deployment Status
To test that all host exporters, Alloy shippers, Kubernetes pods, ClusterIssuers, and HTTPS routes are 100% healthy:
```bash
cd observ-monitory
ansible-playbook -i inventory.ini verify.yml
```

### 3. Uninstall & Clean Up Cluster (Restore to Normal)
To wipe all monitoring pods, delete the `monitoring` namespace, uninstall host exporters, and free up CPU/RAM/disk resources:
```bash
cd observ-monitory
ansible-playbook -i inventory.ini uninstall.yml
```

---

## 💾 Storage Configuration (`group_vars/all.yml`)

You can easily select storage options for **Prometheus** and **Loki** in `group_vars/all.yml` by toggling `enabled: true` or `enabled: false` on your desired storage type:

```yaml
# Prometheus Storage Options
prometheus_storage:
  # Option 1: Dynamic StorageClass (nfs-client, longhorn, local-path, standard, etc.)
  storage_class:
    enabled: true
    name: "nfs-client"
    size: "10Gi"

  # Option 2: HostPath (Direct disk mount on node host)
  host_path:
    enabled: false
    path: "/var/lib/prometheus-data"

  # Option 3: EmptyDir (Ephemeral node disk storage)
  empty_dir:
    enabled: false

  # Option 4: EmptyDir Memory (Ephemeral RAM disk)
  empty_dir_memory:
    enabled: false

# Loki Storage Options
loki_storage:
  # Option 1: Dynamic StorageClass (nfs-client, longhorn, local-path, standard, etc.)
  storage_class:
    enabled: true
    name: "nfs-client"
    size: "10Gi"

  # Option 2: HostPath (Direct disk mount on node host)
  host_path:
    enabled: false
    path: "/var/lib/loki-data"

  # Option 3: EmptyDir (Ephemeral node disk storage)
  empty_dir:
    enabled: false

  # Option 4: EmptyDir Memory (Ephemeral RAM disk)
  empty_dir_memory:
    enabled: false
```


