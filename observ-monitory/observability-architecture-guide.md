# 🔭 Kubernetes Observability & Monitoring Architecture Guide

This guide documents the end-to-end observability and monitoring stack for Kubernetes, covering the **Three Pillars of Observability**:
1. **Metrics** *(Numbers over time: "How much CPU? How many requests?")*
2. **Logs** *(Text events: "Why did it fail? What error message was printed?")*
3. **Traces** *(Request journeys: "Where is the bottleneck across microservices?")*

---

## 1. High-Level Architecture Diagram

```mermaid
flowchart TD
    subgraph Sources["1. DATA SOURCES & AGENTS (Inside Kubernetes Cluster)"]
        nodeExp["Node Exporter<br><i>(Host OS CPU, Disk, RAM, Network)</i>"]
        cadvisor["cAdvisor<br><i>(Container CPU & Memory)</i>"]
        ksm["kube-state-metrics<br><i>(Pod status, Deployments, Replicas)</i>"]
        appLogs["Application Logs<br><i>(stdout / stderr in /var/log/pods)</i>"]
        appTraces["Microservice Apps<br><i>(Instrumented with OpenTelemetry SDK)</i>"]
    end

    subgraph Collection["2. TELEMETRY COLLECTION & ROUTING"]
        otel["OpenTelemetry Collector<br><i>(Universal pipeline for Metrics, Logs, Traces)</i>"]
        promtail["Promtail / Fluent Bit / Alloy<br><i>(Log shipper)</i>"]
    end

    subgraph Storage["3. STORAGE & ANALYSIS ENGINES"]
        prom["Prometheus<br><i>(Time-Series Metrics DB)</i>"]
        loki["Grafana Loki<br><i>(Lightweight Log DB)</i>"]
        elastic["Elasticsearch<br><i>(Full-Text Log Search)</i>"]
        jaeger["Jaeger<br><i>(Distributed Traces DB)</i>"]
    end

    subgraph Actions["4. ALERTING & VISUALIZATION"]
        alertmgr["Alertmanager<br><i>(Routing, de-duplication)</i>"]
        grafana["Grafana<br><i>(Unified UI for Metrics, Logs & Traces)</i>"]
        kibana["Kibana<br><i>(Elasticsearch Search UI)</i>"]
        notifications["Slack / Email / PagerDuty"]
    end

    %% Metrics Flow
    nodeExp -->|Scraped by HTTP /metrics| prom
    cadvisor -->|Scraped by HTTP /metrics| prom
    ksm -->|Scraped by HTTP /metrics| prom
    otel -.->|Can push metrics to| prom

    %% Logs Flow
    appLogs -->|Reads log files| promtail
    promtail -->|Ships logs| loki
    appLogs -.->|Alternative: Beats/Fluentd| elastic

    %% Traces Flow
    appTraces -->|Sends spans via OTLP| otel
    otel -->|Exports traces| jaeger

    %% Alerting Flow
    prom -->|Evaluates alert rules| alertmgr
    alertmgr -->|Sends notifications| notifications

    %% Visualization Flow
    prom -->|PromQL Queries| grafana
    loki -->|LogQL Queries| grafana
    jaeger -->|Trace Queries| grafana
    elastic -->|Search Queries| kibana
```

---

## 2. The Three Pipelines in Detail

### Pipeline A: Metrics (Prometheus + Exporters)
* **Objective:** Answer *"Is the infrastructure healthy, and are resources running out?"*
* **Workflow:**
  1. **Node Exporter** runs as a `DaemonSet` on every cluster node, reading raw Linux kernel metrics (`/proc`, `/sys`) on port `9100`.
  2. **cAdvisor** runs built into the `kubelet` process on each node, tracking container cgroup resource consumption on port `10250`.
  3. **kube-state-metrics** listens to the Kubernetes API server, converting high-level Kubernetes objects (Pods, Deployments, StatefulSets, Nodes) into numerical metrics on port `8080`.
  4. **Prometheus** periodically scrapes these targets via HTTP every 15–30 seconds, storing them in its local time-series database (TSDB).
  5. If an alert condition evaluates to true (e.g., node disk space > 85%), Prometheus triggers an alert to **Alertmanager**.
  6. **Alertmanager** deduplicates, groups, and routes the alert to channels like **Slack**, **PagerDuty**, or **Email**.
  7. Engineers inspect metrics dashboards and graphs in **Grafana** using PromQL.

---

### Pipeline B: Logs (Loki vs. Elasticsearch)
* **Objective:** Answer *"Why did an application crash? What error trace was output?"*
* **Workflow:**
  1. Containerized applications write log events to standard output (`stdout`) and standard error (`stderr`).
  2. The container runtime (e.g., `containerd`) writes these streams to host files under `/var/log/pods/`.
  3. A log agent (**Promtail**, **Grafana Alloy**, or **Fluent Bit**) tails these log files, appends Kubernetes metadata (namespace, pod name, container name), and streams them out.
  4. **Storage Options:**
     * **Grafana Loki (Cloud-Native / LGTM Stack):** Indexes only the metadata labels rather than full text. This keeps storage lightweight, fast, and cost-effective. Logs are queried via **LogQL** inside **Grafana**.
     * **Elasticsearch (ELK / EFK Stack):** Full-text indexes every word in the log stream using Lucene. Provides deep search capabilities at the expense of higher CPU/RAM usage. Searched and analyzed via **Kibana**.

---

### Pipeline C: Distributed Traces (OpenTelemetry + Jaeger)
* **Objective:** Answer *"A user clicked submit and it took 4 seconds. Which microservice or database query caused the delay?"*
* **Workflow:**
  1. Microservice code is instrumented with the **OpenTelemetry (OTel) SDK**.
  2. As incoming HTTP/gRPC requests travel across services (`Frontend` ➔ `Auth` ➔ `Order API` ➔ `Database`), a unique `TraceID` and child `SpanID` headers are injected and propagated.
  3. The microservices send spans via OTLP (OpenTelemetry Protocol, gRPC port `4317` / HTTP port `4318`) to the **OpenTelemetry Collector**.
  4. The Collector batches, filters, and forwards the trace data to **Jaeger**.
  5. Engineers view the trace waterfall diagram in **Grafana** or the Jaeger UI to see exact millisecond latencies for each downstream hop.

---

## 3. Comprehensive Tool Matrix

| Tool | Category | Primary Focus | Default Port | What You Monitor |
| :--- | :--- | :--- | :--- | :--- |
| **Node Exporter** | Host Agent | Host OS Metrics | `9100` | CPU utilization, RAM usage, disk I/O, network bandwidth, filesystem health. |
| **cAdvisor** | Container Agent | Container Metrics | `10250` (via kubelet) | Per-container CPU limit throttling, memory RSS/working set, container restarts. |
| **kube-state-metrics** | Cluster Agent | K8s Object State | `8080` | Pod statuses (CrashLoopBackOff, Pending), Deployment replica counts, PVC binding. |
| **OpenTelemetry** | Framework & Pipeline | Telemetry Collection | `4317` (gRPC), `4318` (HTTP) | Universal collector and router for metrics, logs, and distributed traces. |
| **Prometheus** | Time-Series DB | Metrics Storage & Alert Rules | `9090` | Evaluates PromQL queries, stores time-series metrics, evaluates alert triggers. |
| **Alertmanager** | Alert Engine | Alert Routing & Silencing | `9093` | Deduplicates alerts, manages silence windows, notifies Slack/Teams/PagerDuty/Email. |
| **Loki** | Log Storage | Lightweight Log Storage | `3100` | Application stdout/stderr logs indexed by Kubernetes labels. |
| **Elasticsearch** | Search / Log DB | Full-Text Log Analytics | `9200` | Deep indexing, complex search aggregations, structured application log queries. |
| **Jaeger** | Trace Storage | Distributed Traces | `16686` (UI), `4317` (OTLP) | Microservice call trees, request latency waterfalls, service dependency graphs. |
| **Grafana** | Unified Dashboard | Visualization UI | `3000` | Single pane of glass dashboard combining Prometheus, Loki, and Jaeger. |
| **Kibana** | Analytics UI | Elasticsearch Dashboard | `5601` | Dedicated search UI and visualization interface for Elasticsearch clusters. |

---

## 4. How the Two Primary Stacks Compare

### 1. The Modern Cloud-Native Stack (LGTM Stack)
* **Components:** **L**oki (Logs), **G**rafana (UI), **T**empo / Jaeger (Traces), **M**IMIR / Prometheus (Metrics).
* **Advantages:**
  * Consistent label model: A single label set (e.g., `namespace=dev, pod=order-api-xxx`) links metrics directly to logs and traces inside Grafana.
  * Low resource footprint (especially Loki vs. Elasticsearch).
  * Industry standard for Kubernetes.

### 2. The Classic ELK / EFK Stack
* **Components:** **E**lasticsearch, **L**ogstash / Fluentd, **K**ibana.
* **Advantages:**
  * Rich, full-text free-form search capabilities.
  * Mature enterprise security, machine learning anomaly detection, and SIEM features.
  * Higher storage and memory requirements due to inverted indices.

---

## 5. Where Everything Actually Lives in the Cluster

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ YOUR KUBERNETES CLUSTER                                                                                │
│                                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 🏢 APPLICATION NAMESPACES (e.g. "default", "production")                                          │  │
│  │   • Application Code (Microservices) ➔ Contains embedded OpenTelemetry SDK                        │  │
│  │   • Container stdout/stderr ➔ Writes logs to host disk (/var/log/pods/)                            │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 🛡️ "monitoring" NAMESPACE (Central Management Pods)                                              │  │
│  │   • Prometheus              ➔ StatefulSet Pod (stores metrics on PVC disk)                        │  │
│  │   • Alertmanager            ➔ StatefulSet Pod (handles alert rules & sends to Slack)              │  │
│  │   • Grafana                 ➔ Deployment Pod (Web UI on port 3000)                                │  │
│  │   • Loki                    ➔ StatefulSet Pod (stores logs on PVC/S3 disk)                        │  │
│  │   • Jaeger                  ➔ Deployment Pod (stores traces)                                      │  │
│  │   • kube-state-metrics      ➔ Deployment Pod (polls K8s API server)                               │  │
│  │   • OTel Collector          ➔ Deployment Pod (receives & routes telemetry)                        │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 🚚 RUNS ON EVERY SINGLE NODE (DaemonSets & Node Processes)                                        │  │
│  │   • Node Exporter           ➔ 1 Pod per Node (Mounts host /proc and /sys to read VM hardware)     │  │
│  │   • Promtail / Fluent Bit   ➔ 1 Pod per Node (Mounts host /var/log/pods to ship log files)       │  │
│  │   • cAdvisor                ➔ BUILT DIRECTLY INSIDE kubelet binary (Not even a pod!)              │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Component Location Breakdown

| Component | Where It Actually Stays | Type of Workload | Why It Lives There |
| :--- | :--- | :--- | :--- |
| **cAdvisor** | **Inside `kubelet` binary** on each VM | System process | Compiled directly into Kubernetes `kubelet`. Monitors cgroups directly on the host. |
| **Node Exporter** | **Every VM Node** (GCP + AWS) | `DaemonSet` Pod | Must run on every node to read that specific machine's host CPU, RAM, disk, and network stats. |
| **Promtail / Fluent Bit** | **Every VM Node** (GCP + AWS) | `DaemonSet` Pod | Must run on every node to read `/var/log/pods/` from that node's physical disk. |
| **Microservice Apps** | **Application Namespace** (`default`, `prod`) | App Pods | The OpenTelemetry SDK is imported directly into app code (Go, Python, Java) to track requests. |
| **kube-state-metrics** | **`monitoring` Namespace** | `Deployment` (1-2 Pods) | Talks to the Kubernetes API server (`kube-apiserver`) to count pods, deployments, and replicas. |
| **OpenTelemetry Collector** | **`monitoring` Namespace** | `Deployment` Pod | Central gateway proxy that receives OTLP traces/metrics from apps and forwards them. |
| **Prometheus** | **`monitoring` Namespace** | `StatefulSet` Pod | The central metrics database. Needs a PersistentVolume (PVC) to store historical metric graphs. |
| **Alertmanager** | **`monitoring` Namespace** | `StatefulSet` Pod | Receives alert fires from Prometheus and notifies Slack / Email / PagerDuty. |
| **Loki** | **`monitoring` Namespace** | `StatefulSet` Pod | The central log database. Stores compressed logs on a PersistentVolume or MinIO/S3 bucket. |
| **Jaeger** | **`monitoring` Namespace** | `Deployment` Pod | The central distributed tracing database and query engine. |
| **Grafana** | **`monitoring` Namespace** | `Deployment` Pod | The web dashboard (port `3000`). Exposed to your browser via Ingress or NodePort. |
| **Elasticsearch + Kibana** | **`monitoring` Namespace** OR **Separate VM** | Heavy `StatefulSet` / External VMs | *Alternative to Loki/Grafana.* Placed on separate, heavy VMs due to high memory requirements. |

---

## 6. What About Multiple Clusters in the Future? Enter Thanos!

### The Multi-Cluster Problem with Standard Prometheus:
1. **No Global View:** If you have 3 clusters (e.g. `cluster-aws`, `cluster-gcp`, `cluster-onprem`), standard Prometheus in Cluster A cannot query metrics in Cluster B or C. You would need 3 separate Grafana dashboards!
2. **Short Data Retention:** Prometheus stores data on local SSD/PVC disks. Keeping 1 year of metrics would require terabytes of expensive block storage and slow Prometheus down.
3. **No Cross-Cluster Deduplication:** If you run two Prometheus replicas for High Availability (HA), you get duplicate metrics.

---

### How Thanos Solves It (Global View + Unlimited Object Storage)

```mermaid
flowchart TD
    subgraph Cluster1["KUBERNETES CLUSTER 1 (AWS)"]
        prom1["Prometheus 1"]
        sidecar1["Thanos Sidecar"]
        prom1 --- sidecar1
    end

    subgraph Cluster2["KUBERNETES CLUSTER 2 (GCP)"]
        prom2["Prometheus 2"]
        sidecar2["Thanos Sidecar"]
        prom2 --- sidecar2
    end

    subgraph Cluster3["KUBERNETES CLUSTER 3 (On-Prem / Edge)"]
        prom3["Prometheus 3"]
        sidecar3["Thanos Sidecar"]
        prom3 --- sidecar3
    end

    subgraph S3["CHEAP OBJECT STORAGE (AWS S3 / GCS / MinIO)"]
        bucket[("Long-Term Metrics Bucket<br><i>Years of data at pennies/GB</i>")]
    end

    subgraph Central["CENTRAL MONITORING (Can run in Cluster 1 or dedicated)"]
        store["Thanos Store Gateway<br><i>(Queries historical S3 data)</i>"]
        compactor["Thanos Compactor<br><i>(Downsamples: 5m & 1h resolutions)</i>"]
        querier["Thanos Query (Querier)<br><i>(Global PromQL Engine + Deduplication)</i>"]
        grafana["Unified Grafana Dashboard<br><i>(Select cluster: AWS | GCP | On-Prem)</i>"]
    end

    %% Ship to S3
    sidecar1 -->|Uploads 2h metric blocks| bucket
    sidecar2 -->|Uploads 2h metric blocks| bucket
    sidecar3 -->|Uploads 2h metric blocks| bucket

    %% Queries
    bucket --> store
    compactor -->|Compacts & downsamples| bucket

    querier -->|Real-time queries via gRPC| sidecar1
    querier -->|Real-time queries via gRPC| sidecar2
    querier -->|Real-time queries via gRPC| sidecar3
    querier -->|Historical queries via gRPC| store

    grafana -->|Single PromQL connection| querier
```

---

### The 5 Core Thanos Components Explained

| Thanos Component | Where It Runs | What It Does |
| :--- | :--- | :--- |
| **Thanos Sidecar** | Alongside Prometheus in **EVERY cluster** | 1. Watches Prometheus local TSDB and uploads completed 2-hour blocks to Object Storage (S3/GCS/MinIO).<br>2. Implements the gRPC Store API so Thanos Querier can fetch live/recent metrics directly. |
| **Thanos Query (Querier)** | Central Monitoring / Cluster | The "Single Pane of Glass" query engine. Evaluates PromQL queries, talks to all Sidecars (for live data) and Store Gateways (for historical data), and **deduplicates metrics from HA Prometheus pairs**. |
| **Thanos Store Gateway** | Central Monitoring / Cluster | Serves historical queries by reading old TSDB metric blocks from Object Storage without downloading the entire bucket. |
| **Thanos Compactor** | Central Monitoring (Single replica) | Runs background jobs on the Object Storage bucket to merge blocks and **downsample raw metrics** into 5-minute and 1-hour intervals. This makes 1-year graphs load in seconds! |
| **Thanos Ruler** | Central Monitoring / Cluster | Evaluates alerting and recording rules across all clusters globally. If an alert spans multiple clusters, Thanos Ruler catches it and sends it to Alertmanager. |

---

### Why Thanos is the Industry Standard for Multi-Cluster:
1. **Seamless Migration:** You don't replace Prometheus. You just add the `Thanos Sidecar` to your existing `kube-prometheus-stack` Helm values:
   ```yaml
   prometheus:
     prometheusSpec:
       thanos:
         version: v0.34.0
         objectStorageConfig:
           key: thanos.yaml
           name: thanos-objstore-secret
   ```
2. **Infinite Retention at Low Cost:** Metric blocks go directly to S3 / GCS / MinIO. You can keep 3 years of metrics for pennies per month.
3. **Single Grafana View:** In Grafana, you add a single Prometheus Data Source pointing to `http://thanos-querier:9090`. In your dashboard dropdown, you get a cluster selector: `cluster="aws"`, `cluster="gcp"`, or `cluster="all"`.
