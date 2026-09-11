# Kubespray Cluster Configuration Guide (`group_vars/k8s_cluster/`)

This guide explains the architecture, purpose, configuration options, and real-world examples for all configuration files located in:
`terraform/ansible_kubespray_k8s/kubespray/inventory/sample/group_vars/k8s_cluster/`

---

## 1. Architectural Overview & Group Hierarchy

In Ansible, variables defined inside `group_vars/<group_name>/` are automatically loaded and applied to every host belonging to `<group_name>`.

In Kubespray HA topology:
```ini
[kube_control_plane]
master01 ansible_host=34.x.x.1 ip=10.0.0.1 access_ip=10.0.0.1
master02 ansible_host=34.x.x.2 ip=10.0.0.2 access_ip=10.0.0.2
master03 ansible_host=34.x.x.3 ip=10.0.0.3 access_ip=10.0.0.3

[kube_node]
worker01 ansible_host=54.x.x.1 ip=10.0.0.4 access_ip=10.0.0.4
worker02 ansible_host=54.x.x.2 ip=10.0.0.5 access_ip=10.0.0.5
worker03 ansible_host=54.x.x.3 ip=10.0.0.6 access_ip=10.0.0.6
worker04 ansible_host=54.x.x.4 ip=10.0.0.7 access_ip=10.0.0.7

[k8s_cluster:children]
kube_control_plane
kube_node
```

Because `k8s_cluster` is the parent group of both `kube_control_plane` (GCP) and `kube_node` (AWS), **all variables in this folder apply to all 7 nodes across both cloud providers**.

```
inventory/sample/group_vars/
└── k8s_cluster/
    ├── k8s-cluster.yml          <-- Core cluster settings (K8s version, CIDRs, runtime, CNI selector)
    ├── addons.yml               <-- Platform add-ons (Ingress NGINX, Cert-Manager, Metrics Server)
    ├── kube_control_plane.yml   <-- Resource reservations for control plane hosts
    │
    ├── k8s-net-calico.yml       <-- Calico CNI (ACTIVE in our hybrid WireGuard cluster)
    ├── k8s-net-cilium.yml       <-- Cilium eBPF CNI (dormant)
    ├── k8s-net-flannel.yml      <-- Flannel CNI (dormant)
    ├── k8s-net-kube-ovn.yml     <-- Kube-OVN CNI (dormant)
    ├── k8s-net-kube-router.yml  <-- Kube-Router CNI (dormant)
    ├── k8s-net-macvlan.yml      <-- Macvlan CNI (dormant)
    └── k8s-net-custom-cni.yml   <-- Custom / Helm-based CNI (dormant)
```

> **How CNI selection works**:
> The variable `kube_network_plugin` inside `k8s-cluster.yml` determines which CNI playbook runs. Only the matching `k8s-net-<plugin>.yml` file is evaluated during installation. All other `k8s-net-*.yml` files remain dormant.

---

## 2. Detailed Breakdown of Files

### 2.1 `k8s-cluster.yml` — Core Cluster Configuration
* **Purpose**: The master configuration file for the entire Kubernetes cluster. It specifies Kubernetes binary versions, container runtime engine, cluster network scopes (Pod CIDR & Service CIDR), DNS engine, and security authorization modes.
* **When to Modify**: Whenever adjusting Kubernetes versions, subnet sizes, container runtimes, or switching network plugins.

#### Key Parameters
* `kube_version`: Desired Kubernetes release (e.g., `v1.31.0`).
* `kube_network_plugin`: Selected CNI plugin (`calico`, `cilium`, `flannel`, `kube-ovn`, `kube-router`, `macvlan`, `cni`).
* `kube_pods_subnet`: Subnet range reserved for Pod IP addresses. Must not collide with cloud VPC or WireGuard subnets.
* `kube_service_addresses`: Subnet range reserved for ClusterIP Services.
* `kube_network_node_prefix`: Pod CIDR subnet allocated per individual node (default `/24` allows up to 254 pods per node).
* `container_manager`: Container runtime daemon (`containerd` or `crio`).
* `dns_mode`: Cluster internal DNS daemon (`coredns`).

#### Example Configuration
```yaml
# Kubernetes Core Settings
kube_version: v1.31.0
cluster_name: cluster.local
container_manager: containerd
dns_mode: coredns

# Selected Network Plugin
kube_network_plugin: calico
kube_network_plugin_multus: false

# Subnet Allocations (Disjoint from WireGuard 10.0.0.0/24)
kube_service_addresses: 10.233.0.0/18
kube_pods_subnet: 10.233.64.0/18
kube_network_node_prefix: 24

# Directory Paths
kube_config_dir: /etc/kubernetes
kube_cert_dir: "{{ kube_config_dir }}/ssl"
```

---

### 2.2 `addons.yml` — Built-in Addons & Controllers
* **Purpose**: Manages automated installation of official Kubernetes platform components, including Ingress controllers, TLS cert managers, resource metrics, web dashboards, and local storage provisioners.
* **When to Modify**: When enabling or tailoring essential cluster applications during bootstrap.

#### Key Parameters
* `ingress_nginx_enabled`: Deploys NGINX Ingress Controller.
* `ingress_nginx_service_type`: Service type for ingress (`NodePort` or `LoadBalancer`).
* `cert_manager_enabled`: Installs Jetstack Cert-Manager for automatic ACME (Let's Encrypt) SSL certificates.
* `metrics_server_enabled`: Installs Kubernetes Metrics Server (required for `kubectl top` and HPA autoscalers).
* `helm_enabled`: Installs Helm v3 binary on control plane nodes.
* `dashboard_enabled`: Installs Kubernetes Web Dashboard UI.
* `metallb_enabled`: Installs MetalLB software load balancer.

#### Example Configuration
```yaml
# Helm CLI Installation
helm_enabled: true

# Metrics Server (Resource usage & Pod Autoscaling)
metrics_server_enabled: true
metrics_server_kubelet_insecure_tls: true
metrics_server_metric_resolution: 15s

# NGINX Ingress Controller
ingress_nginx_enabled: true
ingress_nginx_service_type: NodePort
ingress_nginx_service_nodeport_http: 30080
ingress_nginx_service_nodeport_https: 30081

# Cert-Manager (Let's Encrypt TLS Automation)
cert_manager_enabled: true
cert_manager_namespace: "cert-manager"

# Web Dashboard (Disabled by default for security)
dashboard_enabled: false
```

---

### 2.3 `k8s-net-calico.yml` — Calico CNI (Active CNI)
* **Purpose**: Configures Tigera Calico network plugin. Calico provides Pod-to-Pod routing via VXLAN or BGP, network security policies, and IP address management (IPAM).
* **Cross-Cloud WireGuard Specifics**:
  1. **Interface Auto-Detection**: Public cloud nodes have multiple NICs (cloud private VPC IP on `eth0` and WireGuard overlay on `wg0`). Setting `calico_ip_auto_method: "interface=wg.*"` forces Calico to bind to the cross-cloud WireGuard overlay (`10.0.0.x`).
  2. **MTU Clamping**: WireGuard encapsulation requires 80 bytes (giving `wg0` MTU 1420). Calico VXLAN encapsulation adds 50 bytes. Clamping `calico_mtu: 1370` prevents packet fragmentation across the internet.

#### Example Configuration
```yaml
# Calico Backend & Encapsulation
calico_network_backend: vxlan
calico_vxlan_mode: 'Always'
calico_vxlan_port: 4789
calico_vxlan_vni: 4096

# MTU Clamping (1420 wg0 MTU - 50 VXLAN header = 1370)
calico_mtu: 1370
calico_veth_mtu: 1370

# WireGuard Mesh Interface Auto-Detection
calico_ip_auto_method: "interface=wg.*"

# Outbound NAT for internet access from pods
nat_outgoing: true
calico_pool_blocksize: 26
```

---

### 2.4 `k8s-net-cilium.yml` — Cilium eBPF CNI
* **Purpose**: Configures Cilium, a high-performance CNI based on Linux eBPF. Replaces `iptables` and `kube-proxy` with in-kernel eBPF programs, providing L3/L4/L7 security policies, integrated Hubble network visibility, and native service load balancing.
* **When to Modify**: When `kube_network_plugin: cilium` is enabled in `k8s-cluster.yml`.

#### Key Parameters
* `cilium_kube_proxy_replacement`: Set to `"true"` to eliminate `kube-proxy` entirely.
* `cilium_tunnel_mode`: Tunneling mode (`vxlan` or `geneve`).
* `cilium_mtu`: Custom MTU clamped for underlying tunnels.
* `cilium_enable_hubble`: Enables Hubble observability engine.
* `cilium_hubble_ui`: Deploys Hubble graphical service map UI.

#### Example Configuration
```yaml
# Kube-Proxy Replacement with eBPF
cilium_kube_proxy_replacement: "true"

# Overlay Tunneling & MTU
cilium_tunnel_mode: "vxlan"
cilium_mtu: 1370

# Observability (Hubble)
cilium_enable_hubble: true
cilium_hubble_ui: true
cilium_hubble_metrics:
  - dns
  - drop
  - tcp
  - flow
  - icmp
  - http
```

---

### 2.5 `k8s-net-custom-cni.yml` — Custom / Helm CNI
* **Purpose**: Used when `kube_network_plugin: cni`. Allows bringing your own CNI deployment via custom Kubernetes manifests or upstream Helm charts instead of Kubespray's bundled CNI roles.
* **When to Modify**: When testing custom CNI plugins, unbundled CNIs (e.g., Antrea, Weave), or specific vendor enterprise releases.

#### Example Configuration (Helm Deployment)
```yaml
custom_cni_chart_namespace: kube-system
custom_cni_chart_release_name: cilium
custom_cni_chart_repository_name: cilium
custom_cni_chart_repository_url: https://helm.cilium.io
custom_cni_chart_ref: cilium/cilium
custom_cni_chart_version: "1.15.5"
custom_cni_chart_values:
  cluster:
    name: "hybrid-k8s"
  tunnel: "vxlan"
```

---

### 2.6 `k8s-net-flannel.yml` — Flannel Lightweight CNI
* **Purpose**: Configures CoreOS Flannel, a minimalist overlay network plugin. It is simple to operate and uses VXLAN, `host-gw`, or WireGuard backend encapsulation.
* **Limitations**: Flannel does **not** support Kubernetes `NetworkPolicy` objects (pod firewall isolation).

#### Example Configuration
```yaml
flannel_interface_regexp: '10\.0\.0\.\d{1,3}'
flannel_backend_type: "vxlan"
flannel_vxlan_port: 8472
flannel_vxlan_vni: 1
```

---

### 2.7 `k8s-net-kube-ovn.yml` — Kube-OVN Enterprise SDN CNI
* **Purpose**: Bridges Open vSwitch (OVS) and Open Virtual Network (OVN) to Kubernetes. Delivers advanced data center network features including multi-tenancy, custom VPCs, fixed IP addresses, QoS traffic shaping, gateway high availability, and hardware acceleration.
* **When to Modify**: Complex multi-tenant enterprise topologies requiring isolated virtual overlay routers inside Kubernetes.

#### Example Configuration
```yaml
kube_ovn_network_type: geneve
kube_ovn_tunnel_type: geneve
kube_ovn_node_switch_cidr: 100.64.0.0/16
kube_ovn_enable_lb: true
kube_ovn_enable_np: true
kube_ovn_enable_external_vpc: true
```

---

### 2.8 `k8s-net-kube-router.yml` — Kube-Router All-in-One CNI
* **Purpose**: A lightweight, unified solution that combines:
  1. Pod networking using Linux IP routing and standard BGP.
  2. Ingress `NetworkPolicy` controller using `iptables`/`ipset`.
  3. Service proxy (replacing `kube-proxy`) using high-performance IPVS.
* **When to Modify**: Bare-metal and colocation environments peering with external top-of-rack (ToR) BGP switches.

#### Example Configuration
```yaml
kube_router_run_router: true
kube_router_run_firewall: true
kube_router_run_service_proxy: true
kube_router_cluster_asn: 64512
```

---

### 2.9 `k8s-net-macvlan.yml` — Macvlan L2 Direct CNI
* **Purpose**: Attaches container pods directly to the host's physical L2 ethernet interface via Linux Macvlan sub-interfaces. Each pod receives an IP and MAC address directly on the underlying physical switch subnet, bypassing any overlay or NAT overhead.
* **Cloud Note**: **Not compatible with AWS or GCP**. Public cloud hypervisors (AWS Nitro / GCP Andromeda) enforce strict source/destination IP and MAC checking and discard Macvlan traffic. Used almost exclusively on bare metal.

#### Example Configuration
```yaml
macvlan_interface: "eth1"
enable_nat_default_gateway: true
```

---

### 2.10 `kube_control_plane.yml` — Control Plane Resource Reservations
* **Purpose**: Configures resource reservations (`systemReserved` and `kubeReserved`) specifically on Kubernetes Control Plane nodes. Guarantees that Linux kernel daemons (systemd, sshd, wireguard) and core Kubernetes components (kube-apiserver, etcd, kube-controller-manager) will never be starved of CPU, RAM, or PIDs by user pods.
* **When to Modify**: Production clusters under high workload pressure to ensure master node resilience.

#### Example Configuration
```yaml
# Reservation for Kubernetes daemons (kubelet, runtime)
kube_memory_reserved: 512Mi
kube_cpu_reserved: 200m
kube_ephemeral_storage_reserved: 2Gi
kube_pid_reserved: "1000"

# Reservation for underlying Linux OS & WireGuard daemon
system_memory_reserved: 512Mi
system_cpu_reserved: 250m
system_ephemeral_storage_reserved: 2Gi
system_pid_reserved: "1000"
```

---

## 3. Summary Reference Matrix

| Configuration File | Scope | Status in this Cluster | Key Responsibilities |
| :--- | :--- | :--- | :--- |
| **`k8s-cluster.yml`** | Entire Cluster | **Active** | Core K8s version, CNI selector, Pod/Service CIDRs, container runtime. |
| **`addons.yml`** | Entire Cluster | **Active** | Ingress NGINX, Cert-Manager, Metrics Server, Dashboard, Helm. |
| **`k8s-net-calico.yml`** | Entire Cluster | **Active** | Calico VXLAN overlay, MTU 1370 clamping, WireGuard `wg0` autodetection. |
| **`kube_control_plane.yml`** | Control Plane | Configurable | Memory/CPU/PID resource reservations for master nodes. |
| **`k8s-net-cilium.yml`** | Entire Cluster | Dormant | eBPF-based alternative CNI (active only if `kube_network_plugin: cilium`). |
| **`k8s-net-custom-cni.yml`** | Entire Cluster | Dormant | Custom manifest/Helm CNI (active only if `kube_network_plugin: cni`). |
| **`k8s-net-flannel.yml`** | Entire Cluster | Dormant | Flannel CNI (active only if `kube_network_plugin: flannel`). |
| **`k8s-net-kube-ovn.yml`** | Entire Cluster | Dormant | Kube-OVN CNI (active only if `kube_network_plugin: kube-ovn`). |
| **`k8s-net-kube-router.yml`** | Entire Cluster | Dormant | Kube-router CNI (active only if `kube_network_plugin: kube-router`). |
| **`k8s-net-macvlan.yml`** | Entire Cluster | Dormant | Macvlan CNI (active only if `kube_network_plugin: macvlan`). |

---

## 4. End-to-End Deployment Flow

In our hybrid infrastructure, the deployment flow follows three automated steps:

```
┌────────────────────────────────────────────────────────┐
│ 1. Terraform (Cloud VMs + Security Groups + Firewalls) │
│    - GCP 3 Masters (34.x.x.x public / 10.10.x.x VPC)   │
│    - AWS 4 Workers (54.x.x.x public / 10.20.x.x VPC)   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. WireGuard Full Mesh Playbook (terraform/wiregurad)  │
│    - Installs WireGuard, enables IP forwarding         │
│    - Establishes full-mesh wg0 (10.0.0.1 - 10.0.0.7)   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. Kubespray Cluster Playbook (ansible_kubespray_k8s)   │
│    - Connects via ansible_host (public IP)             │
│    - Binds daemons to ip & access_ip (10.0.0.x on wg0) │
│    - Calico auto-detects wg0 with MTU 1370             │
└────────────────────────────────────────────────────────┘
```
