# 🏛️ Complete Architecture & End-to-End Traffic Flow Diagram

This document details the exact architecture, network pathways, and protocol layers connecting public internet clients to the Kubernetes observability stack deployed across the hybrid GCP + AWS cluster.

---

## 🌐 1. End-to-End HTTPS Request & Data Flow

```mermaid
flowchart TD
    subgraph Internet["🌐 PUBLIC INTERNET (Users & Browsers)"]
        user1["👨‍💻 Client Browser<br><code>https://grafana.seang.shop</code>"]
        user2["👨‍💻 Client Browser<br><code>https://opensearch.seang.shop</code>"]
    end

    subgraph CloudflareEdge["☁️ CLOUDFLARE ANYCAST EDGE"]
        cfDNS["📡 Cloudflare DNS<br>• <code>grafana.seang.shop</code> ➔ CNAME <code>tunnel-id.cfargotunnel.com</code> (Proxied)<br>• <code>opensearch.seang.shop</code> ➔ CNAME <code>tunnel-id.cfargotunnel.com</code> (Proxied)"]
        cfSSL["🔒 Cloudflare Edge TLS<br>• Universal Edge SSL Certificate (*.seang.shop)<br>• TLS 1.3 / HTTP/2 & HTTP/3 (QUIC) Termination<br>• DDoS Protection & Web Application Firewall (WAF)"]
        cfTunnelEdge["🚇 Cloudflare Argo Tunnel Edge<br>• Dynamic Traffic Director<br>• Dispatches requests over active QUIC connections"]
    end

    subgraph TunnelWire["🔒 SECURE ENCRYPTED TUNNEL (NO OPEN INBOUND PORTS)"]
        quicConn["⚡ Persistent Outbound QUIC/UDP Connections<br>• Established from INSIDE Kubernetes to Cloudflare Edge<br>• 0 Open Firewall Inbound Ports on GCP / AWS<br>• Multiplexed Stream Management"]
    end

    subgraph K8sCluster["☸️ HYBRID KUBERNETES CLUSTER (GCP AMD64 + AWS ARM64)"]

        subgraph TraefikNS["📦 Namespace: traefik"]
            cfd["🚇 cloudflared DaemonSet / Deployment (2 Replicas)<br>• Reads TUNNEL_TOKEN<br>• Forwards all tunnel streams to internal Gateway<br><code>--url https://traefik.traefik.svc.k8scluster:443 --no-tls-verify</code>"]
            
            traefikGW["🚦 Traefik Gateway Controller (v3)<br>• Kind: <code>Gateway (gateway.networking.k8s.io/v1)</code><br>• Secret: <code>traefik-gateway-tls</code> (*.seang.shop)<br>• Service: <code>traefik.traefik.svc.k8scluster:443</code>"]
        end

        subgraph RoutingRules["🔀 Kubernetes Gateway API HTTPRoutes"]
            routeGrafana["🔀 HTTPRoute: <code>grafana-httproute</code><br>• Hostname: <code>grafana.seang.shop</code><br>• Target: <code>prometheus-grafana:80</code>"]
            routeProm["🔀 HTTPRoute: <code>prometheus-httproute</code><br>• Hostname: <code>prometheus.seang.shop</code><br>• Target: <code>prometheus-kube-prometheus-prometheus:9090</code>"]
            routeOS["🔀 HTTPRoute: <code>opensearch-dashboards-httproute</code><br>• Hostname: <code>opensearch.seang.shop</code><br>• Target: <code>opensearch-dashboards:5601</code>"]
        end

        subgraph MonitoringNS["📦 Namespace: monitoring (Observability Core)"]
            grafanaApp["📊 Grafana (3 Replicas)<br>• Service: <code>prometheus-grafana:80</code><br>• Web UI & Dashboards for Metrics, Logs, Traces"]
            promEngine["🔥 Prometheus (2 Replicas)<br>• TSDB Metrics Engine<br>• Storage: 15Gi Longhorn Volume"]
            lokiEngine["🟠 Loki (StatefulSet)<br>• Log Aggregation Engine<br>• Storage: 15Gi Longhorn Volume"]
            jaegerApp["🟣 Jaeger (Deployment)<br>• Distributed Tracing Backend & Query UI"]
            alloyDaemon["🟣 Grafana Alloy (DaemonSet)<br>• Tails <code>/var/log/pods/*</code> on all VMs<br>• Receives OTLP Traces & Ships to Loki & Jaeger"]
            nodeExpDaemon["📟 Node Exporter (DaemonSet on all 7 VMs)<br>• Exports host CPU, Memory, Disk, Network to Prometheus"]
        end

        subgraph OpenSearchNS["📦 Namespace: opensearch (Log Analytics & SIEM)"]
            osDashboards["🔎 OpenSearch Dashboards (Deployment)<br>• Service: <code>opensearch-dashboards:5601</code><br>• Queries OpenSearch Backend"]
            osCluster["⚡ OpenSearch Cluster (StatefulSet on master01)<br>• Service: <code>opensearch-cluster-all-in-one:9200</code><br>• Full-text search & log document indexer"]
        end

    end

    %% Client Request Flow
    user1 -->|1. HTTPS :443| cfDNS
    user2 -->|1. HTTPS :443| cfDNS
    cfDNS --> cfSSL
    cfSSL --> cfTunnelEdge
    cfTunnelEdge -->|2. Encrypted Tunnel Stream| quicConn
    quicConn -->|3. Inbound over established tunnel| cfd
    
    %% Inside Cluster Routing Flow
    cfd -->|4. Internal HTTPS :443 with Host Header| traefikGW
    traefikGW -->|5a. Match Host: grafana.seang.shop| routeGrafana
    traefikGW -->|5b. Match Host: opensearch.seang.shop| routeOS
    
    routeGrafana -->|6a. ClusterIP:80| grafanaApp
    routeOS -->|6b. ClusterIP:5601| osDashboards

    %% Internal Data Queries
    grafanaApp -->|PromQL Query| promEngine
    grafanaApp -->|LogQL Query| lokiEngine
    grafanaApp -->|Trace Query| jaegerApp
    osDashboards -->|REST Query :9200| osCluster

    %% Internal Telemetry Collection
    alloyDaemon -->|Push Logs :3100| lokiEngine
    alloyDaemon -->|Export Traces :4317| jaegerApp
    nodeExpDaemon -->|Scraped by :9090| promEngine
```

---

## 🔒 2. Automated TLS Certificate Issuance (DNS-01 ACME Challenge)

How the wildcard certificate `*.seang.shop` is generated and renewed automatically without exposing port 80 to the public:

```mermaid
sequenceDiagram
    autonumber
    actor Admin as 🤖 Ansible Playbook / cert-manager
    participant CM as 🛡️ cert-manager Controller
    participant LE as 🌐 Let's Encrypt (ACME Server)
    participant CF as ☁️ Cloudflare DNS API
    participant Secret as 🔑 K8s Secret (traefik-gateway-tls)
    participant Traefik as 🚦 Traefik Gateway

    Admin->>CM: Deploy Certificate Manifest (*.seang.shop & seang.shop)
    CM->>LE: 1. Request Certificate via DNS-01 Challenge (Order Created)
    LE-->>CM: 2. Return DNS-01 challenge token (e.g. _acme-challenge.seang.shop)
    CM->>CF: 3. Create TXT Record "_acme-challenge.seang.shop" using cloudflare_api_token
    CF-->>CM: 4. TXT Record Published
    CM->>LE: 5. Notify Let's Encrypt that DNS record is ready
    LE->>CF: 6. Let's Encrypt queries Cloudflare Authoritative DNS to verify TXT record
    CF-->>LE: 7. TXT record verified successfully
    LE-->>CM: 8. Issue Signed Wildcard TLS Certificate (Valid 90 days)
    CM->>CF: 9. Cleanup & delete temporary TXT record
    CM->>Secret: 10. Store tls.crt & tls.key in "traefik-gateway-tls" Secret
    Secret->>Traefik: 11. Traefik hot-reloads TLS Secret without restart
```

---

## 🗺️ 3. Physical Node Topology & Workload Placement

The cluster spans two public clouds interconnected via an encrypted **Calico WireGuard mesh** on internal subnet `10.0.0.0/24`:

```mermaid
flowchart TD
    subgraph GCP["☁️ GOOGLE CLOUD (asia-east1) — High Memory Compute (8 GB RAM each)"]
        subgraph M1["Node: master01 (Control Plane, AMD64, 8GB RAM)"]
            m1_core["kube-apiserver<br>etcd<br>kube-controller"]
            m1_os["⚡ OpenSearch Cluster (Single Node)<br>• Heap: 512MB RAM + Lucene Engine<br>• NodeSelector: arch=amd64"]
            m1_prom["🔥 Prometheus TSDB Server<br>• Storage: 15Gi Longhorn PV"]
            m1_loki["🟠 Loki Log Server<br>• Storage: 15Gi Longhorn PV"]
            m1_jaeger["🟣 Jaeger Tracing Backend"]
            m1_agents["Alloy & Node Exporter"]
        end

        subgraph M2["Node: master02 (Control Plane, AMD64, 8GB RAM)"]
            m2_core["kube-apiserver<br>etcd<br>kube-controller"]
            m2_traefik["🚦 Traefik Gateway Pod"]
            m2_grafana["📊 Grafana Server (3 Replicas)"]
            m2_osd["🔎 OpenSearch Dashboards (1 Replica)"]
            m2_cert["🛡️ cert-manager Webhook & Cainjector"]
            m2_agents["Alloy & Node Exporter"]
        end
    end

    subgraph AWS["☁️ AMAZON WEB SERVICES (ap-southeast-1) — Light Compute (2 GB RAM each)"]
        subgraph M3["Node: master03 (Control Plane, ARM64, 2GB RAM)"]
            m3_core["kube-apiserver<br>etcd<br>calico-node"]
            m3_agents["Node Exporter (Burstable QoS: 20Mi)"]
        end

        subgraph Workers["Worker Nodes: worker01, worker02, worker03, worker04 (ARM64, 2GB RAM each)"]
            w_cloudflared["🚇 cloudflared Tunnel Replicas (2 Pods)"]
            w_alert["🚨 Alertmanager StatefulSet"]
            w_cert["🛡️ cert-manager Core Controller"]
            w_agents["Alloy & Node Exporter DaemonSets"]
        end
    end

    subgraph StorageLayer["💾 DISTRIBUTED PERSISTENT STORAGE (Longhorn CSI)"]
        lh_prom[("pvc-prometheus-db<br>15 GiB RWO Block Volume")]
        lh_loki[("pvc-storage-loki-0<br>15 GiB RWO Block Volume")]
    end

    m1_prom --- lh_prom
    m1_loki --- lh_loki
```

---

## ⚡ 4. Step-by-Step Request Lifecycle Breakdown

| Step | Component | Protocol | Description |
| :---: | :--- | :---: | :--- |
| **1** | **Browser Client** | `HTTPS (443)` | User visits `https://grafana.seang.shop` or `https://opensearch.seang.shop`. |
| **2** | **Cloudflare DNS** | `DNS` | Resolves to Cloudflare Anycast edge IP (`104.21.28.65` / `172.67.144.150`) via proxied CNAME to `2749c806-0e57-4941-a095-a86501f9ac2c.cfargotunnel.com`. |
| **3** | **Cloudflare Edge** | `TLS 1.3` | Cloudflare terminates edge TLS with trusted public certificate, performs DDoS inspection, and locates active tunnel connections. |
| **4** | **Argo Tunnel** | `QUIC / UDP` | Cloudflare encapsulates the HTTP/2 stream into the existing outbound QUIC connection established by the in-cluster `cloudflared` pod. |
| **5** | **`cloudflared` Pod** | `Internal HTTPS` | The pod decapsulates the stream and forwards it internally to `https://traefik.traefik.svc.k8scluster:443` preserving the original `Host:` header. |
| **6** | **Traefik Gateway** | `Gateway API` | Traefik presents the Let's Encrypt wildcard certificate (`*.seang.shop`), inspects the `Host` header, and matches the corresponding `HTTPRoute`. |
| **7** | **HTTPRoute Dispatch** | `ClusterIP` | • `grafana.seang.shop` ➔ routed to `prometheus-grafana.monitoring.svc.k8scluster:80`<br>• `opensearch.seang.shop` ➔ routed to `opensearch-dashboards.opensearch.svc.k8scluster:5601`. |
| **8** | **Application Backends** | `HTTP` | Grafana and OpenSearch Dashboards process the request and stream the rendered UI back through the tunnel to the user's browser with **`HTTP/2 200/302`**. |
