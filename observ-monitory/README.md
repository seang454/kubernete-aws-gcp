# 📊 Kubernetes Observability & Monitoring Ansible Project (`observ-monitory`)

This Ansible project automates the deployment, verification, and teardown of the complete cloud-native observability stack for Kubernetes, covering **Metrics**, **Logs**, and **Distributed Traces**.

For detailed architecture diagrams and component relationships, see the [Observability Architecture Guide](./observability-architecture-guide.md).

---

## 📁 Modular Roles Architecture

Each component has its own dedicated role following its suitable Kubernetes deployment model:

```text
observ-monitory/
├── ansible.cfg                    # Ansible configuration with keepalives
├── inventory.ini                  # Hybrid K8s Cluster Inventory (GCP + AWS)
├── site.yml                       # Master deploy playbook (Runs all 5 roles + verify)
├── verify.yml                     # Automated health verification playbook
├── uninstall.yml                  # Teardown playbook wiping monitoring & freeing resources
├── group_vars/
│   └── all.yml                    # Global toggles, storage classes, credentials, domains
├── roles/
│   ├── prometheus_stack/          # Metrics: Prometheus, Alertmanager, Grafana, Node Exporter, kube-state-metrics, cAdvisor
│   ├── loki_stack/                # Logs: Loki (StatefulSet) + Promtail (DaemonSet)
│   ├── jaeger/                    # Traces: Jaeger Tracing Backend & Query UI (Deployment)
│   ├── opentelemetry/             # Telemetry Pipeline: OpenTelemetry Collector (Deployment)
│   └── grafana_dashboards/        # UI: Curated dashboards for Cluster, Nodes, Pods, Logs, Traces
└── observability-architecture-guide.md
```

---

## 🚀 Execution Instructions

### 1. Deploy the Complete Monitoring Stack
Deploys Prometheus, Alertmanager, Grafana, Node Exporter, kube-state-metrics, Loki, Promtail, Jaeger, and OpenTelemetry Collector:
```bash
cd observ-monitory
ansible-playbook -i inventory.ini site.yml
```

### 2. Verify System Health & Pod Status
Checks that all 10 observability components, DaemonSets on all 7 nodes, and datasources are running:
```bash
cd observ-monitory
ansible-playbook -i inventory.ini verify.yml
```

### 3. Uninstall & Clean Up Cluster
Uninstalls all Helm releases, deletes the `monitoring` namespace, and frees up all CPU, RAM, and storage:
```bash
cd observ-monitory
ansible-playbook -i inventory.ini uninstall.yml
```

---

## ⚙️ Component Configuration (`group_vars/all.yml`)

You can enable or disable any role independently in `group_vars/all.yml`:

```yaml
enable_prometheus_stack: true    # Metrics (Prometheus + Alertmanager + Grafana + Exporters)
enable_loki_stack: true          # Logs (Loki + Promtail)
enable_jaeger: true              # Traces (Jaeger)
enable_opentelemetry: true       # OTel Collector pipeline
enable_grafana_dashboards: true  # Pre-built Dashboards
```

### Storage Configuration (Longhorn by default)
```yaml
default_storage_class: "longhorn"

prometheus_storage:
  storage_class:
    enabled: true
    name: "longhorn"
    size: "15Gi"
  retention: "15d"

loki_storage:
  storage_class:
    enabled: true
    name: "longhorn"
    size: "15Gi"
  retention: "168h"              # 7 days
```

---

## ✅ The Complete Checklist: What Gets Installed

| Tool You Asked For | Installed By Which Role? | How It Runs in Kubernetes | Status |
| :--- | :--- | :--- | :---: |
| **1. Prometheus** | `prometheus_stack` | `StatefulSet` Pod + Longhorn Storage | ✅ **YES** |
| **2. Grafana** | `prometheus_stack` | `Deployment` Pod (Port 3000 Web UI) | ✅ **YES** |
| **3. Alertmanager** | `prometheus_stack` | `StatefulSet` Pod (Slack / Email alerts) | ✅ **YES** |
| **4. Node Exporter** | `prometheus_stack` | `DaemonSet` (Runs on **all 7 nodes**) | ✅ **YES** |
| **5. cAdvisor** | `prometheus_stack` | Scrapes **`kubelet` on all 7 nodes** | ✅ **YES** |
| **6. kube-state-metrics** | `prometheus_stack` | `Deployment` Pod (Cluster object stats) | ✅ **YES** |
| **7. Loki** | `loki_stack` | `StatefulSet` Pod + Longhorn Storage | ✅ **YES** |
| **8. Promtail** | `loki_stack` | `DaemonSet` (Tails logs on **all 7 nodes**) | ✅ **YES** |
| **9. Jaeger** | `jaeger` | `Deployment` Pod + Service (Tracing UI) | ✅ **YES** |
| **10. OpenTelemetry Collector** | `opentelemetry` | `Deployment` Pod (OTLP Ports 4317/4318) | ✅ **YES** |
| **11. Elasticsearch + Kibana** | Replaced by **Loki + Grafana** | Cloud-Native Log Engine in Grafana | 💡 **Optimized** |

---

### Why Loki + Grafana Instead of Elasticsearch + Kibana?

* **Resource Footprint:** Elasticsearch + Kibana requires **8GB to 16GB+ of RAM** just to idle. Because your worker nodes are lightweight cloud instances (`t3.small`), running Elasticsearch would cause immediate **Out-Of-Memory (OOM) crashes**.
* **Efficiency:** Loki + Grafana gives you the exact same log aggregation, search, and dashboard capabilities using **less than 1GB of RAM**.
* **Unified UI:** All logs collected by Promtail go directly into Loki, and you search them inside **Grafana** right next to your Prometheus metrics and Jaeger traces (single pane of glass)!
