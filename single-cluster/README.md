# 📊 Kubernetes Observability & Monitoring Ansible Project (`observ-monitory`)

This Ansible project automates the deployment, verification, and teardown of the complete cloud-native observability stack for Kubernetes, covering **Metrics**, **Logs**, and **Distributed Traces**.

For complete architecture diagrams and deep-dive explanations, see the [Observability Architecture Guide](./observability-architecture-guide.md).

---

## 🗺️ Master Observability Architecture

```mermaid
flowchart TD
    subgraph Sources["1. DATA SOURCES & AGENTS (Inside Kubernetes Cluster)"]
        nodeExp["Node Exporter<br><i>(Host OS CPU, Disk, RAM, Network)</i>"]
        cadvisor["cAdvisor<br><i>(Container cgroup CPU & Memory)</i>"]
        ksm["kube-state-metrics<br><i>(Pod status, Deployments, Replicas)</i>"]
        appLogs["Application Logs<br><i>(stdout / stderr in /var/log/pods)</i>"]
        appOTel["Microservice Apps<br><i>(Instrumented with OpenTelemetry SDK)</i>"]
        appPyro["App Runtimes / eBPF<br><i>(Instrumented with Pyroscope Agent)</i>"]
    end

    subgraph Pipeline["2. UNIFIED TELEMETRY COLLECTION & PIPELINE"]
        alloy["🟣 Grafana Alloy / OpenTelemetry Collector<br><i>(All-in-One Universal Shipper for Metrics, Logs, Traces & Profiles)</i>"]
    end

    subgraph Storage["3. STORAGE & ANALYSIS ENGINES (The 4 Pillars)"]
        prom["🔥 Prometheus / Mimir / Thanos<br><i>(Metrics Engine: PromQL)</i>"]
        loki["🟠🟡 Grafana Loki<br><i>(Log Engine: LogQL)</i>"]
        tempo["🟠 Grafana Tempo / Jaeger<br><i>(Tracing Engine: TraceQL)</i>"]
        pyro["🟠 Grafana Pyroscope<br><i>(Profiling Engine: Flame Graphs)</i>"]
        s3[("Cloud Object Storage<br><i>AWS S3 / GCS / MinIO<br>(Cheap Long-Term Storage)</i>")]
    end

    subgraph Actions["4. ALERTING & VISUALIZATION (Single Pane of Glass)"]
        alertmgr["Alertmanager<br><i>(Alert deduplication & routing)</i>"]
        grafana["🟠 Grafana (Unified Web Dashboard)<br><i>(Single UI for Metrics, Logs, Traces & Profiles)</i>"]
        notifications["Team Alerts<br><i>(Slack, PagerDuty, Email)</i>"]
    end

    %% Ingestion into Collection Pipeline
    nodeExp -->|Scraped HTTP /metrics| prom
    cadvisor -->|Scraped HTTP /metrics| prom
    ksm -->|Scraped HTTP /metrics| prom
    appLogs -->|Tails log files| alloy
    appOTel -->|Sends OTLP Traces & Metrics| alloy
    appPyro -->|Sends CPU/Memory Profiles| alloy

    %% Pipeline routing to Storage
    alloy -->|Pushes or exposes Metrics| prom
    alloy -->|Pushes compressed Logs| loki
    alloy -->|Pushes Traces via OTLP| tempo
    alloy -->|Pushes Profile Snapshots| pyro

    %% Long-term Object Storage offload
    loki -.->|Archives log chunks| s3
    tempo -.->|Archives trace blocks| s3
    pyro -.->|Archives profile blocks| s3
    prom -.->|Optional: Thanos/Mimir offload| s3

    %% Alerting Flow
    prom -->|Fires alert rules| alertmgr
    alertmgr -->|Sends notifications| notifications

    %% Visualization Queries from Grafana
    prom -->|PromQL Queries| grafana
    loki -->|LogQL Queries| grafana
    tempo -->|TraceQL Queries| grafana
    pyro -->|Flame Graph Queries| grafana
```

### 🧠 Unified Mental Model: How All 4 Pillars Connect

```text
                               ┌──────────────────────────────────────────────┐
                               │             🟠 GRAFANA (WEB UI)              │
                               │   "The Single Pane of Glass to see it all"   │
                               └──────┬──────────┬──────────┬──────────┬──────┘
                                      │          │          │          │
   ┌──────────────────────────────────┴──┐ ┌─────┴─────┐ ┌──┴───────┐ ┌┴─────────────────┐
   │        🔥 PROMETHEUS / MIMIR        │ │ 🟠🟡 LOKI │ │ 🟠 TEMPO │ │  🟠 PYROSCOPE    │
   │               METRICS               │ │   LOGS    │ │  TRACES  │ │     PROFILES     │
   │        "Is the server slow?"        │ │ "Any error│ │ "Which ms│ │ "Which exact line│
   │                                     │ │ message?" │ │ is slow?"│ │  of code burned  │
   │                                     │ │           │ │          │ │    the CPU?"     │
   └──────────────────▲──────────────────┘ └───▲───────┘ └───▲──────┘ └────────▲─────────┘
                      │                        │             │                 │
                      └────────────────────────┼─────────────┴─────────────────┘
                                               │
                                 ┌─────────────┴─────────────┐
                                 │     🟣 GRAFANA ALLOY      │
                                 │ "The All-in-One Collector"│
                                 └─────────────▲─────────────┘
                                               │
                                     [ YOUR APPLICATIONS ]
```

---

### 🏢 Enterprise / Big Project Scale Architecture

For high-scale multi-cluster environments, this architecture scales out into a distributed platform with streaming buffers and object storage:

```mermaid
flowchart TD
    subgraph Edge["🌐 EDGE CLUSTERS (AWS, GCP, On-Prem)"]
        apps["Apps (OTel SDK) & Exporters"]
        kps["🔥 kube-prometheus-stack + Thanos Sidecar"]
        alloy["🟣 Grafana Alloy (Edge Agent)<br><i>• PII Redaction • Metric Filtering • Tail-Sampling</i>"]
        apps --> alloy
        apps -.->|Metrics| kps
    end

    subgraph Queue["⚡ RESILIENCE BUFFER (Logs, Traces, Profiles)"]
        kafka["📨 Apache Kafka / Redpanda<br><i>(Absorbs 50x outage retry storms)</i>"]
        alloy --> kafka
    end

    subgraph StorageCluster["🏢 CENTRAL STORAGE & DATA LAKE"]
        s3[("Cloud Object Storage (AWS S3 / GCS)<br><i>• Metrics 2h blocks + downsamples<br>• Loki log chunks & Tempo traces</i>")]
        
        kps -->|Uploads 2h TSDB Blocks| s3
        thanos["🔥 Thanos Stack (Querier + Store Gateway + Compactor)"]
        s3 <--> thanos
        kps -.->|gRPC Live Queries <2h| thanos

        kafka --> loki["🟠🟡 Loki HA"]
        kafka --> tempo["🟠 Tempo HA"]
        kafka --> pyro["🟠 Pyroscope HA"]

        loki --> s3
        tempo --> s3
        pyro --> s3
    end

    subgraph Governance["🎯 ACCESS & GOVERNANCE (Single Pane of Glass)"]
        gw["Multi-Tenant Gateway (SSO / RBAC / Quotas)"]
        grafana["🟠 Unified Grafana Enterprise / HA<br><i>Dropdown: [ All Clusters | AWS | GCP ]</i>"]
        thanos --> gw
        loki --> gw
        tempo --> gw
        pyro --> gw
        gw --> grafana
    end
```

> [!NOTE]
> **Why are the labels different between the Cluster and Enterprise diagrams? (The Camera Metaphor)**  
> The workloads are **100% identical under the hood**.
> - **In the Single-Cluster Diagram:** We zoom in (10x) to show every individual piece (`Microservice Apps (OTel SDK)`, `Node Exporter`, `cAdvisor`, `kube-state-metrics`, `Pyroscope`).
> - **In the Enterprise Diagram:** We zoom out (1x) across 50 clusters, summarizing those same 6 pieces into **`Microservices & Daemons`**, and labeling Grafana Alloy as **`🟣 Grafana Alloy (Edge Agent)`** to emphasize its role scrubbing PII and tail-sampling traces at the edge.

> 📖 **Deep Dive:** For the complete scaling blueprint, tail-sampling configuration, and distributed Helm values, see [Section 10: Enterprise Scaling Blueprint](./observability-architecture-guide.md#10-enterprise-scaling-blueprint-adapting-for-big-project-production-scale).

---

## 📁 Project Structure

```text
observ-monitory/
├── ansible.cfg                          # Ansible configuration with SSH keepalives
├── inventory.ini                        # Hybrid K8s Cluster Inventory (GCP + AWS)
├── site.yml                             # Master deploy playbook (Runs all roles + verify)
├── verify.yml                           # Automated health verification playbook
├── uninstall.yml                        # Teardown playbook wiping monitoring & freeing resources
├── group_vars/
│   └── all.yml                          # Global toggles, storage classes, credentials, domains
├── roles/
│   ├── prometheus_stack/                # Role 1: Metrics & Alerting Engine (Prometheus, Alertmanager, Grafana)
│   ├── loki_stack/                      # Role 2: Log Aggregation Engine (Loki)
│   ├── jaeger/                          # Role 3: Distributed Tracing Backend (Jaeger OTLP)
│   ├── opensearch/                      # Role 4: Full-Text Search, Audit & SIEM (OpenSearch + Dashboards)
│   ├── kafka/                           # Role 5: Resilience Buffer & Streaming Queue (Bitnami Kafka + Kafka UI)
│   ├── debezium/                        # Role 6: CDC & Schema Registry (Debezium Connect + Schema Registry)
│   ├── alloy/                           # Role 7: Universal Telemetry Shipper (Grafana Alloy DaemonSet)
│   ├── opentelemetry/                   # Role 8: Telemetry Pipeline Router (Standalone OTel Collector)
│   ├── grafana_dashboards/              # Role 9: Curated Visual Dashboards
│   ├── host_observability/              # Role 10: Non-K8s External Host Exporters (Alloy + Node Exporter)
│   └── ceph_observability/              # Role 11: External Ceph Cluster Exporter
└── observability-architecture-guide.md
```

---

## 📦 What Each Role Installs & When to Use It

### 1. `roles/prometheus_stack` (Inside Kubernetes)
* **What it installs:**
  * **Prometheus Operator**: Manages Prometheus and Alertmanager lifecycle via CRDs.
  * **Prometheus**: Time-series metrics database (`StatefulSet` with Longhorn PVC storage, port `9090`).
  * **Alertmanager**: Deduplicates and routes alerts to Slack/PagerDuty/Email (`StatefulSet`, port `9093`).
  * **Grafana**: Unified visualization dashboard UI (`Deployment`, port `3000`).
  * **Node Exporter**: DaemonSet pod running on **all 7 Kubernetes nodes** to collect host CPU, RAM, disk, and network stats (port `9100`).
  * **kube-state-metrics**: Deployment pod polling the Kubernetes API server for Pod, Deployment, and PVC health (port `8080`).
  * **cAdvisor integration**: Configures scraping of container cgroup metrics directly from `kubelet` on each node (port `10250`).
* **Deployment Method:** Helm chart `prometheus-community/kube-prometheus-stack`.
* **When to use:** Required for all Kubernetes metrics, hardware monitoring, and Grafana dashboards.

---

### 2. `roles/loki_stack` (Inside Kubernetes)
* **What it installs:**
  * **Loki**: Cloud-native log aggregation database (`StatefulSet` with Longhorn PVC storage, port `3100`).
  * **Promtail**: DaemonSet pod running on **all 7 Kubernetes nodes** tailing container stdout/stderr logs from `/var/log/pods/`.
  * **Grafana Datasource ConfigMap**: Auto-wires Loki as a data source into Grafana with label `grafana_datasource: "1"`.
* **Deployment Method:** Helm chart `grafana/loki-stack`.
* **When to use:** Required for centralized container and application log collection with LogQL search in Grafana.

---

### 3. `roles/jaeger` (Inside Kubernetes)
* **What it installs:**
  * **Jaeger All-in-One**: Distributed tracing backend and query engine (`Deployment`, image `jaegertracing/all-in-one:1.64.0`).
  * **Jaeger Service**: Exposes port `16686` (Web Query UI), port `4317` (OTLP gRPC), and port `4318` (OTLP HTTP).
  * **Grafana Datasource ConfigMap**: Auto-wires Jaeger as a tracing data source into Grafana with label `grafana_datasource: "1"`.
* **Deployment Method:** Kubernetes native `Deployment` and `Service` manifests.
* **When to use:** Required for distributed microservice tracing, latency waterfall views, and service dependency maps.

---

### 4. `roles/opentelemetry` (Inside Kubernetes)
* **What it installs:**
  * **OpenTelemetry Collector**: Universal telemetry proxy and pipeline (`Deployment`, image `otel/opentelemetry-collector-contrib:0.118.0`).
  * **Pipeline Configuration**: Receives application traces and metrics over OTLP (`4317` gRPC / `4318` HTTP). Batches and routes traces to Jaeger and exposes metrics on port `8889` for Prometheus.
  * **OTel Service**: Exposes `otel-collector` inside the cluster so applications can send telemetry to `http://otel-collector.monitoring.svc:4317`.
* **Deployment Method:** Kubernetes native `Deployment`, `ConfigMap`, and `Service` manifests.
* **When to use:** Legacy/alternative collector. In Architecture 1.1, `roles/alloy` is preferred as the universal unified shipper.
* **Architecture Note (SDK in App vs. Collector in K8s):**
  * **In Applications:** Developers embed the **OpenTelemetry SDK** (`@opentelemetry/sdk`, Java agent, Go SDK) into their code to generate traces.
  * **In Kubernetes:** The **Collector** runs as a central gateway. Apps dump telemetry locally to the Collector in `< 1ms` (zero application slowdown), and the Collector handles batching, PII redaction, retries, and routing to Jaeger/Loki/Prometheus without touching application code. *(See full deep dive in [observability-architecture-guide.md](file:///home/seang/kubernete-aws-gcp/single-cluster/observability-architecture-guide.md#24-deep-dive-why-install-opentelemetry-in-kubernetes-if-its-already-in-the-application))*.

---

### 5. `roles/opensearch` (Inside Kubernetes)
* **What it installs:**
  * **OpenSearch**: Distributed full-text search, audit logging, and SIEM engine (`StatefulSet` on Longhorn PVC, port `9200`). Tuned for small nodes (`-Xms512m -Xmx512m`).
  * **OpenSearch Dashboards**: Specialized web console for log discovery, search aggregations, and security analytics (port `5601`).
  * **Grafana Datasource ConfigMap**: Automatically registers OpenSearch into Grafana via sidecar discovery.
* **Deployment Method:** Helm chart `opensearch/opensearch` and `opensearch/opensearch-dashboards`.
* **When to use:** Required for full-text search, regulatory audit logging, SIEM security analysis, and deep log analytics.

---

### 6. `roles/kafka` (Inside Kubernetes - Confluent 3-Node KRaft Cluster)
* **What it installs:**
  * **Confluent CP-Kafka 7.8.0 (3-Node KRaft Cluster)**: 3-broker / 3-controller cluster (`kafka-1-itp`, `kafka-2-itp`, `kafka-3-itp`) running in KRaft mode (no ZooKeeper required).
  * **Network & Storage**: Dedicated Services for each node (`:9090` plaintext, `:9091` controller, `:9092` external) + cluster-wide `kafka` service, with dedicated Longhorn PVC storage for each broker.
* **Deployment Method:** Kubernetes native `StatefulSet`, `Service`, and `PersistentVolumeClaim` manifests.
* **Controlled By:** Toggle `enable_kafka: false` (defaulted to `false` until you want to spin it up).

---

### 7. `roles/schema_registry` (Inside Kubernetes - Confluent Schema Registry)
* **What it installs:**
  * **Confluent CP-Schema-Registry 7.8.0 (`schema-registry-itp`)**: Schema management service (port `8081`) for managing and enforcing Apache Avro schemas across Kafka topics.
  * **Storage & Persistence**: PVC `schema-registry-itp-data` mounted at `/etc/schema-registry/data`.
* **Deployment Method:** Kubernetes native `Deployment`, `Service`, and `PersistentVolumeClaim` manifests.
* **Controlled By:** Toggle `enable_schema_registry: false`.

---

### 8. `roles/debezium` (Inside Kubernetes - Debezium Kafka Connect CDC)
* **What it installs:**
  * **Debezium Kafka Connect (`debezium-kafka-connect-itp`)**: Distributed CDC engine (port `8083`) with Avro converters configured for real-time Database Change Data Capture (PostgreSQL WAL, MySQL binlog, Oracle).
  * **Storage & Plugins**: PVCs for `/kafka/connect/plugins` and `/kafka/data`.
  * **Custom Dockerfile**: Stored in `roles/debezium/files/Dockerfile` with Confluent Avro converters, Confluent JDBC, and Oracle Instant Client 19c.
* **Deployment Method:** Kubernetes native `Deployment`, `Service`, and `PersistentVolumeClaim` manifests.
* **Controlled By:** Toggle `enable_debezium: false`.

---

### 9. `roles/kafka_ui` (Inside Kubernetes - Provectus Kafka UI)
* **What it installs:**
  * **Provectus Kafka UI (`kafka-ui-itp`)**: Visual web management console (port `8080`) with built-in login form authentication (`admin` / `qwer`).
  * **Full Integration**: Pre-wired to inspect all 3 Kafka brokers, the Schema Registry (`http://schema-registry-itp:8081`), and Debezium Connect (`http://debezium-kafka-connect-itp:8083`).
  * **Storage**: PVC `kafka-ui-itp-data` mounted at `/data`.
* **Deployment Method:** Kubernetes native `Deployment`, `Service`, and `PersistentVolumeClaim` manifests.
* **Controlled By:** Toggle `enable_kafka_ui: false`.

---

### 10. `roles/alloy` (Inside Kubernetes)
* **What it installs:**
  * **Grafana Alloy**: Universal telemetry shipper running as a `DaemonSet` on **every Kubernetes node**.
  * **Log Tailing**: Directly mounts `/var/log/pods/` to ship container stdout/stderr to Loki or OpenSearch.
  * **Trace Receiver**: Listens on ports `4317` (gRPC) and `4318` (HTTP) for in-cluster OTLP traces from microservices and forwards them to Jaeger.
* **Deployment Method:** Helm chart `grafana/alloy`.
* **When to use:** The central unified collector for Architecture 1.1 (replaces standalone Promtail and standalone OTel Collector).
* **Architecture Note (All-in-One Collector):**
  > [!NOTE]
  > **Is Alloy used to make all types of collectors in one place? YES!**
  > Rather than running 4 separate DaemonSets on every worker node (Promtail for logs, Prometheus Scraper for metrics, OpenTelemetry Collector for traces, and Pyroscope for profiles)—which would consume ~600MB RAM on every node—**Grafana Alloy combines all 4 collector engines into a single lightweight DaemonSet (~120MB RAM)**. See full deep dive in [observability-architecture-guide.md](file:///home/seang/kubernete-aws-gcp/single-cluster/observability-architecture-guide.md#25-deep-dive-is-grafana-alloy-used-to-make-all-types-of-collectors-in-one-place).

---

### 11. `roles/grafana_dashboards` (Inside Kubernetes)
* **What it installs:**
  * Curated, pre-built visual dashboards deployed as Kubernetes `ConfigMaps` with the label `grafana_dashboard: "1"`.
  * Grafana's dashboard sidecar automatically detects these ConfigMaps and imports them into Grafana:
    * **Loki Log Engine Dashboard**
    * **Ingress / Web Traffic Dashboard**
    * **Ceph Storage Cluster Dashboard** (if Ceph is enabled)
    * **NFS-Ganesha Storage Dashboard** (if Ganesha is enabled)
    * **MinIO S3 Storage Dashboard** (if MinIO is enabled)
* **Deployment Method:** Kubernetes `ConfigMap` resources.
* **When to use:** Provides instant out-of-the-box visualization without manual JSON dashboard imports.

---

### 12. `roles/host_observability` (OUTSIDE Kubernetes — Standalone VMs)
* **What it installs:**
  * **prometheus-node-exporter**: Installs Node Exporter via `apt` as a Linux background `systemd` service on port `9100`.
  * **Grafana Alloy**: Installs Alloy via `apt` as a Linux background `systemd` service to tail `/var/log/syslog` on the host VM and stream logs into Loki.
* **Deployment Method:** Linux APT package management and systemd service management.
* **When to use:** Only used for **external, bare-metal, or standalone servers OUTSIDE Kubernetes** (e.g. standalone database VMs, Ceph storage nodes) that cannot run Kubernetes pods. If all your servers are Kubernetes nodes, this role is not needed.

---

### 13. `roles/ceph_observability` (OUTSIDE Kubernetes — Ceph Storage)
* **What it installs:**
  * Enables the Ceph Manager Prometheus exporter module (`ceph mgr module enable prometheus`) on port `9283`.
* **Deployment Method:** Ceph administrative CLI commands.
* **When to use:** Only used if you run an external Ceph storage cluster and want Prometheus to scrape pool health, OSD status, and IOPS.

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
| **8. Grafana Alloy** | `alloy` | `DaemonSet` (All-in-one shipper on **all 7 nodes**) | ✅ **YES** |
| **9. Jaeger** | `jaeger` | `Deployment` Pod + Service (Tracing UI) | ✅ **YES** |
| **10. OpenTelemetry Collector** | `opentelemetry` / `alloy` | Built into Alloy or standalone Deployment | ✅ **YES** |
| **11. OpenSearch & Dashboards** | `opensearch` | StatefulSet + Dashboards Deployment | ✅ **YES** |
| **12. Kafka KRaft Cluster** | `kafka` | 3-Node StatefulSet cluster | 🟡 Optional toggle |
| **13. Debezium & Schema Registry** | `debezium`, `schema_registry` | CDC Connect + Avro Registry Deployments | 🟡 Optional toggle |
| **14. Kafka UI** | `kafka_ui` | Web Management Console Deployment | 🟡 Optional toggle |

---

### Why Loki + Grafana Instead of Elasticsearch + Kibana?

* **Resource Footprint:** Elasticsearch + Kibana requires **8GB to 16GB+ of RAM** just to idle. Because your worker nodes are lightweight cloud instances (`t3.small`), running Elasticsearch would cause immediate **Out-Of-Memory (OOM) crashes**.
* **Efficiency:** Loki + Grafana gives you the exact same log aggregation, search, and dashboard capabilities using **less than 1GB of RAM**.
* **Unified UI:** All logs collected by Alloy go directly into Loki, and you search them inside **Grafana** right next to your Prometheus metrics and Jaeger traces (single pane of glass)!

---

## 🚀 Execution Instructions

### 1. Deploy the Complete Monitoring Stack
Deploys Prometheus, Alertmanager, Grafana, Node Exporter, kube-state-metrics, Loki, Alloy, Jaeger, OpenSearch, and optional Kafka/CDC components:
```bash
cd ~/kubernete-aws-gcp/single-cluster
ansible-playbook -i inventory.ini site.yml
```

### 2. Verify System Health & Pod Status
Checks that all observability components, DaemonSets on all 7 nodes, and datasources are running:
```bash
cd ~/kubernete-aws-gcp/single-cluster
ansible-playbook -i inventory.ini verify.yml
```

### 3. Uninstall & Clean Up Cluster
Uninstalls all Helm releases, deletes the `monitoring` namespace, and frees up all CPU, RAM, and storage:
```bash
cd ~/kubernete-aws-gcp/single-cluster
ansible-playbook -i inventory.ini uninstall.yml
```
