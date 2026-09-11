# 🏗️ Production-Ready Observability & Monitoring Architecture Guide
## HA Ceph + NFS-Ganesha + Kubernetes Storage Infrastructure

This guide defines the end-to-end production observability architecture combining **Prometheus**, **Grafana**, **Grafana Loki**, **Grafana Alloy**, and **OpenTelemetry** for the **HA Ceph + NFS-Ganesha + Kubernetes Storage Infrastructure**.

---

## 📐 Unified System Architecture Diagram

```text
========================================================================================================================
                                          📊 VISUALIZATION & ALERTING LAYER
========================================================================================================================
                                            ┌─────────────────────────────┐
                                            │  📊 GRAFANA WEB DASHBOARD   │
                                            │    (Single Unified Pane)    │
                                            └──────────────┬──────────────┘
                                                           │ (PromQL / LogQL Queries)
                           ┌───────────────────────────────┴───────────────────────────────┐
                           ▼                                                               ▼
            ┌─────────────────────────────┐                                 ┌─────────────────────────────┐
            │ 📈 PROMETHEUS SERVER (HA)   │                                 │ 📜 GRAFANA LOKI LOG ENGINE  │
            │ (Local Storage / Decoupled) │                                 │ (Local Storage / Object DB) │
            └──────────────▲──────────────┘                                 └──────────────▲──────────────┘
                           │                                                               │
                           │ (Scrape / Remote Write)                                       │ (Loki HTTP Push / OTLP)
===========================│===============================================================│============================
                           │                      🛰️ TELEMETRY COLLECTION LAYER             │
===========================│===============================================================│============================
                           │                                                ┌──────────────┴──────────────┐
                           │                                                │ 🚀 GRAFANA ALLOY AGENT      │
                           │                                                │ (K8s DaemonSet & Host Svc)  │
                           │                                                └──────────────▲──────────────┘
                           │                                                               │
      ┌────────────────────┴────────────────────┐                           ┌──────────────┴──────────────┐
      │ • ceph-mgr-prometheus (Port 9283)       │                           │ • OTLP Ports 4317/4318      │
      │ • node_exporter (Port 9100)             │                           │ • Ganesha Multiline Logs    │
      │ • ganesha_exporter (Port 9587)          │                           │ • Journald & K8s Stdout     │
      │ • ha_cluster_exporter (Port 9664)       │                           └──────────────▲──────────────┘
      │ • kube-state-metrics (Port 8080)        │                                          │
      └────────────────────▲────────────────────┘                                          │
                           │                                                               │
===========================│===============================================================│============================
                           │                 💾 INFRASTRUCTURE & APPLICATION WORKLOADS     │
===========================│===============================================================│============================
   [ 📦 HA Ceph + NFS Storage Host Nodes ]                           [ ☸️ K8s Worker Nodes & App Workloads ]
   • haproxy-1 (10.140.0.2)                                         • k8s-worker-1 .. 5
   • haproxy-2 (10.140.0.3)                                         • 🔌 App Pods with OpenTelemetry SDK
   • haproxy-3 (10.140.0.4)                                           (Emitting OTLP metrics/logs to Alloy)
   • VIP: 10.140.0.5 (Pacemaker Managed)
========================================================================================================================
```

---

## 🛡️ Production-Ready Critical Architecture Principles

### 1. Decoupled Monitoring Storage (Avoiding Circular Storage Deadlock)
> [!CAUTION]
> **Never store Prometheus TSDB metrics or Loki log indices on the NFS volume being monitored!**
> If the HA Ceph/NFS storage cluster experiences a crash or latency freeze, any monitoring database running on that NFS share will also lock up and crash. This leaves operators blind during an outage.
> **Solution**: Use local storage (`local-path-provisioner` or NVMe `hostPath`) or remote S3/Ceph RGW object storage for Prometheus and Loki data.

### 2. Dedicated Storage Gateway & HA Exporters
* Standard `node_exporter` only captures kernel OS metrics (CPU, RAM, general disk bytes).
* Production monitoring requires:
  * **`ganesha_exporter` (Port 9587)**: Exposes NFSv4 IOPS, RPC latencies (`READ`, `WRITE`, `GETATTR`), active client mounts, and FSAL queue depth.
  * **`ha_cluster_exporter` (Port 9664)**: Exposes Pacemaker/Corosync cluster quorum state, Virtual IP active host location, and failover event counts.

### 3. Structured Grafana Alloy Log Parsing
* Tailing `/var/log/ganesha/ganesha.log` raw produces unstructured string logs in Loki.
* Grafana Alloy must be configured with multiline aggregation and regex parsing stages for Ganesha log severities (`NIV_WARN`, `NIV_CRIT`, `NIV_EVENT`) and Ceph FSAL error tags.

---

## 🧱 Component Breakdown & Architecture Roles

### 1. Visualization & Alerting Layer
* **Grafana (Central Dashboard)**: Single-pane-of-glass interface visualizing Ceph health, NFS IOPS, host performance, and log streams.
* **Alertmanager**: Evaluates threshold rules and routes alerts via Slack, PagerDuty, or Email when storage degradations or failovers occur.

### 2. Central Data Storage Layer (Decoupled)
* **Prometheus Server**: High-availability time-series database storing metrics scraped from storage host exporters and Kubernetes components.
* **Grafana Loki**: Log indexing engine storing and parsing logs from systemd, NFS-Ganesha, Ceph daemons, and K8s container pods.

### 3. Telemetry Collection & Agent Layer
* **Grafana Alloy (Host & K8s DaemonSet)**: OpenTelemetry-native unified collector agent. Ships host system logs (`/var/log/ganesha/ganesha.log`, `journald`) and container stdout/stderr to Loki.
* **Ceph Prometheus Plugin (`ceph-mgr-prometheus`)**: Native Ceph module exporting OSD latency, PG status, pool bytes, and cluster health directly on port 9283.
* **Node Exporter (Port 9100)**: Host metrics agent capturing OS CPU, memory, disk SMART health, and network interfaces.
* **Ganesha Exporter (Port 9587)**: Captures NFSv4 protocol IOPS, latency, and client connection counts.
* **HA Cluster Exporter (Port 9664)**: Captures Pacemaker/Corosync quorum and Virtual IP location.
* **Kube-State-Metrics (Port 8080)**: Exposes Kubernetes storage object metrics (PVC requested vs consumed, PV binding status).

---

## 📊 Telemetry Data Flow Matrix

| Source Component | Data Type | Collector Agent | Target Backend | Primary Metric / Log Key |
| :--- | :--- | :--- | :--- | :--- |
| **Ceph Storage Cluster** | Metrics | `ceph-mgr-prometheus` | Prometheus | `ceph_pool_bytes_used`, `ceph_osd_up`, `ceph_health_status` |
| **NFS-Ganesha Server** | Gateway Metrics | `ganesha_exporter` | Prometheus | `ganesha_nfs_stats_read_bytes`, `ganesha_nfs_stats_write_latency` |
| **Pacemaker / Corosync** | HA Status | `ha_cluster_exporter` | Prometheus | `pacemaker_failcount`, `pacemaker_location`, `corosync_quorate` |
| **Linux Host OS** | Host Metrics | `node_exporter` | Prometheus | `node_filesystem_free_bytes`, `node_disk_io_time_seconds_total` |
| **NFS-Ganesha Daemon** | Logs | Grafana Alloy (Host Svc) | Grafana Loki | `/var/log/ganesha/ganesha.log` (`NIV_CRIT`, `FSAL_CEPH`) |
| **Kubernetes PVCs** | Storage Metrics | `kube-state-metrics` | Prometheus | `kubelet_volume_stats_used_bytes`, `kube_persistentvolumeclaim_status_phase` |
| **App Pods (K8s)** | Telemetry | OpenTelemetry SDK | Grafana Alloy | Container stdout/stderr & OTLP metrics |

---

## 🚨 Production Threshold & Alerting Rules

| Alert Rule Name | Condition | Severity | Description | Action Required |
| :--- | :--- | :--- | :--- | :--- |
| `CephPoolNearFull` | Pool storage > 80% | ⚠️ Warning | Storage pool reaching capacity limit. | Add new OSD disk or clean unused files. |
| `CephPoolCritical` | Pool storage > 90% | 🚨 Critical | High risk of Ceph read-only freeze. | Immediate expansion or deletion of old snapshots. |
| `NFSGaneshaDown` | Ganesha process inactive | 🚨 Critical | NFS service crashed on active gateway node. | Pacemaker failover check / restart service. |
| `NFSGaneshaHighLatency` | `ganesha_nfs_stats_write_latency > 500ms` | ⚠️ Warning | NFS write latency is abnormally high. | Inspect Ceph OSD disk queue & pool IOPS. |
| `PacemakerQuorumLost` | `corosync_quorate == 0` | 🚨 Critical | Pacemaker cluster lost quorum. | Inspect network pings on UDP 5404/5405 across HA storage nodes. |
| `PacemakerVIPSwitched` | `changes(pacemaker_location{resource="VIP"}[5m]) > 0` | ℹ️ Info / Warn | Virtual IP `10.140.0.5` failed over. | Check `/var/log/messages` on `haproxy-1` to diagnose root cause. |
| `CephOSDDown` | `ceph_osd_up == 0` | 🚨 Critical | One or more storage physical drives offline. | Inspect host disk `/dev/sdb` & replace drive. |
| `CephPGDegraded` | `ceph_pg_degraded > 0` | ⚠️ Warning | Placement groups are degraded/under-replicated. | Check OSD drive status and cluster connectivity. |
| `K8sPVCFull` | PVC usage > 85% | ⚠️ Warning | Pod volume filling up. | Expand PVC size in K8s StorageClass. |

---

## 🗺️ Deployment Placement & Justification Map

```text
========================================================================================================================
📍 LOCATION 1: HA STORAGE HOST NODES (`haproxy-1`, `haproxy-2`, `haproxy-3`)
👉 WHY HERE? Ceph, NFS-Ganesha, Pacemaker, and raw hard drives (/dev/sdb) run directly on the host Linux OS.
========================================================================================================================
  1. 🟢 ceph-mgr-prometheus  ──► Ceph Manager Module (Port 9283)
                                  └─► WHY: Reads Ceph OSD health, IOPS & pool space directly from Ceph daemon.
  2. 🟢 node_exporter        ──► Linux Host OS Systemd Service (Port 9100)
                                  └─► WHY: Reads physical host CPU, RAM, network & disk SMART health.
  3. 🟢 ganesha_exporter     ──► Linux Host OS Systemd Service (Port 9587)
                                  └─► WHY: Measures NFSv4 IOPS, RPC latencies & active client mount counts.
  4. 🟢 ha_cluster_exporter  ──► Linux Host OS Systemd Service (Port 9664)
                                  └─► WHY: Measures Pacemaker/Corosync quorum state and VIP node location.
  5. 🚀 Grafana Alloy (Host) ──► Linux Host OS Systemd Service
                                  └─► WHY: Tails `/var/log/ganesha/ganesha.log` and journald log streams.

========================================================================================================================
📍 LOCATION 2: KUBERNETES CLUSTER (Namespace: `monitoring`)
👉 WHY HERE? K8s provides automated container management, high availability, and single-URL ingress for dashboards.
========================================================================================================================
  6. 📈 Prometheus Server    ──► K8s StatefulSet (Stores metrics on LOCAL Storage - local-path)
                                  └─► WHY: Decoupled local storage ensures monitoring survives storage cluster outages.
  7. 📜 Grafana Loki         ──► K8s StatefulSet (Stores logs on LOCAL Storage or S3/RGW Object DB)
                                  └─► WHY: Decoupled persistent log engine protected against NFS lockups.
  8. 📊 Grafana Web UI       ──► K8s Deployment (Exposed via Ingress/NodePort on Port 3000)
                                  └─► WHY: Unified web dashboard accessible to all DevOps & developer teams.
  9. 🚀 Grafana Alloy (K8s)  ──► K8s DaemonSet (Runs 1 pod on every node for OTLP & container logs)
                                  └─► WHY: K8s container stdout logs (/var/log/pods) exist on worker node hosts.
 10. ⚙️ Kube-State-Metrics   ──► K8s Deployment
                                  └─► WHY: Queries the Kubernetes API directly for PVC, PV, and Pod statuses.

========================================================================================================================
📍 LOCATION 3: INSIDE APPLICATION SOURCE CODE (K8s App Pods)
👉 WHY HERE? Application performance (file write speed to NFS, API latency, custom app errors) is captured in-process.
========================================================================================================================
 11. 🔌 OpenTelemetry SDK    ──► Library inside App Code (Spring Boot / Node.js / Python)
                                  └─► WHY: Emits custom application OTLP metrics and logs over ports 4317/4318.
========================================================================================================================
```

---

## 📋 Placement Matrix & Architectural Rationale

| Tool | Where to Deploy | Installation Method | Why It MUST Be Installed There |
| :--- | :--- | :--- | :--- |
| **`ceph-mgr-prometheus`** | HA Storage Nodes (`haproxy-1..3`) | CLI: `ceph mgr module enable prometheus` | Only the Ceph Manager daemon has direct access to internal Ceph OSD and pool stats. |
| **`node_exporter`** | HA Storage Nodes (`haproxy-1..3`) | Linux `systemd` service | Captures bare-metal/VM kernel metrics, disk SMART health, and `/var/log` filesystem capacity. |
| **`ganesha_exporter`** | HA Storage Nodes (`haproxy-1..3`) | Linux `systemd` service | Captures NFS-Ganesha protocol metrics (NFS IOPS, RPC latencies, active mounts). |
| **`ha_cluster_exporter`** | HA Storage Nodes (`haproxy-1..3`) | Linux `systemd` service | Measures Pacemaker/Corosync HA cluster status, quorum health, and VIP location. |
| **Grafana Alloy (Host)** | HA Storage Nodes (`haproxy-1..3`) | Linux package as `systemd` service | Tails host logs (`/var/log/ganesha/ganesha.log` & journald) directly from the OS filesystem. |
| **Prometheus Server** | Kubernetes Cluster (`monitoring`) | Helm: `kube-prometheus-stack` | Runs in K8s using **local storage** (`storageClassName: local-path`) to decouple from NFS outages. |
| **Grafana Loki** | Kubernetes Cluster (`monitoring`) | Helm: `loki-stack` | Runs in K8s using **local storage** or S3/RGW object storage to remain independent of NFS. |
| **Grafana Web UI** | Kubernetes Cluster (`monitoring`) | Helm: `kube-prometheus-stack` | Exposed via K8s Ingress/NodePort (`http://<K8S_IP>:3000`) for central UI access. |
| **Grafana Alloy (K8s)** | Kubernetes Worker Nodes (All 5) | K8s DaemonSet (via Helm) | Tails container log files (`/var/log/pods`) directly on worker node hosts. |
| **OpenTelemetry SDK** | Inside App Code (K8s Pods) | App dependency (`npm`, `pip`, `maven`) | Captures inside-app timers (e.g. NFS write performance from within application code). |

---

## 🚀 Complete Step-by-Step Execution Commands

### 1. On Ceph Manager Nodes (`haproxy-1`):
```bash
# Enable native Ceph Prometheus exporter (Exposes metrics on port 9283)
sudo ceph mgr module enable prometheus

# Verify Ceph exporter service
sudo ceph mgr services
```

### 2. On HA Storage Host Nodes (`haproxy-1`, `haproxy-2`, `haproxy-3`):
```bash
# 1. Install node_exporter for OS hardware metrics (Port 9100)
sudo apt-get update && sudo apt-get install -y prometheus-node-exporter

# 2. Install Grafana Alloy for host NFS/Ceph logs
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/grafana.gpg > /dev/null
echo "deb https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install -y alloy
sudo systemctl enable --now alloy

# 3. Configure Alloy log pipeline (/etc/alloy/config.alloy)
sudo cat << 'EOF' > /etc/alloy/config.alloy
loki.relabel "ganesha_logs" {
  forward_to = [loki.write.local_loki.receiver]
  rule {
    target_label = "job"
    replacement  = "nfs-ganesha"
  }
  rule {
    target_label = "host"
    replacement  = constants.hostname
  }
}

loki.source.file "ganesha_file" {
  targets = [
    { "__path__" = "/var/log/ganesha/ganesha.log" },
  ]
  forward_to = [loki.relabel.ganesha_logs.receiver]
}

loki.write "local_loki" {
  endpoint {
    url = "http://10.140.0.5:3100/loki/api/v1/push"
  }
}
EOF

sudo systemctl restart alloy
```

### 3. On Kubernetes Master Node (`k8s-master-1`):
```bash
# 1. Create monitoring namespace
kubectl create namespace monitoring

# 2. Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. Deploy Prometheus + Grafana Stack (Using LOCAL Storage to decouple from NFS outages)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=local-path \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# 4. Deploy Loki + Alloy Log Stack (Using LOCAL Storage to decouple from NFS outages)
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.storageClassName=local-path \
  --set loki.persistence.size=50Gi \
  --set alloy.enabled=true
```
