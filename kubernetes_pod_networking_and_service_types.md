# Kubernetes Networking: `Pod.spec` Networking Modes vs. `Service.spec.type`

In Kubernetes, networking is divided into two distinct layers that are frequently confused:

1. **`Service.spec.type`**: Controls how traffic from inside or outside the cluster is routed and load-balanced to pods via `kube-proxy` and virtual IPs.
2. **`Pod.spec` Networking Modes**: Controls how an individual pod connects to the physical node's network stack (isolated CNI overlay vs. host interface).

---

## High-Level Architecture: Two-Layer Networking

```mermaid
flowchart TD
    Client["Client / User"] --> Layer1["Layer 1: Service.spec.type (Routing & Virtual IPs)"]

    subgraph ServiceLayer["Service Types (kube-proxy / iptables / IPVS)"]
        Layer1 -->|External Cloud LB| LB["LoadBalancer"]
        Layer1 -->|High Host Port 30000-32767| NP["NodePort"]
        Layer1 -->|Internal Virtual IP| CIP["ClusterIP"]
        Layer1 -->|DNS CNAME Alias| EN["ExternalName"]
    end

    CIP --> Layer2["Layer 2: Pod.spec (Pod Network Namespace)"]
    NP --> Layer2
    LB --> Layer2

    subgraph PodLayer["Pod Networking Modes"]
        Layer2 -->|Default: Isolated Overlay IP 10.233.x.x| Standard["Standard CNI Pod Network"]
        Layer2 -->|Host Network Stack: Node IP directly| HostNet["hostNetwork: true"]
        Layer2 -->|Hybrid: Overlay IP + Port Mapping| HostPort["hostPort Mapping"]
    end
```

---

# Part 1: Diagrams for Each `Service.spec.type`

---

### 1. `ClusterIP` (Standard Internal Virtual IP)

* **How it works:** A stable virtual IP (VIP) is allocated inside the cluster. `kube-proxy` programs `iptables` or IPVS on every node to load balance traffic across matching pod IPs. It is accessible **only within the cluster**.

#### Diagram: `ClusterIP` Traffic Flow

```mermaid
flowchart LR
    PodA["Client Pod A (IP: 10.233.64.10)"] -->|1. Request 'backend-svc:80'| DNS["CoreDNS"]
    DNS -->|2. Resolves to VIP| VIP["ClusterIP VIP (10.233.10.50:80)"]
    
    VIP -->|3. kube-proxy load balances| PodB1["Backend Pod 1 (IP: 10.233.65.12:8080)"]
    VIP -->|3. kube-proxy load balances| PodB2["Backend Pod 2 (IP: 10.233.66.15:8080)"]
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP  # Default if omitted
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80         # Port exposed by the Service
      targetPort: 8080 # Port where the app listens in the pod
```

---

### 2. Headless Service (`ClusterIP: None`)

* **How it works:** When `clusterIP: None` is set, Kubernetes does **not** allocate a virtual IP. CoreDNS directly returns the A records of the matching individual Pod IPs. Used for StatefulSets (Kafka brokers, Cassandra nodes, Redis clusters) where clients must connect directly to a specific instance.

#### Diagram: Headless Service (`ClusterIP: None`)

```mermaid
flowchart TD
    ClientPod["Client Pod"] -->|1. Lookup 'db-service'| DNS["CoreDNS"]
    DNS -->|2. Returns List of All Pod IPs| ClientPod
    
    ClientPod -->|Direct TCP: 10.233.65.21| DB0["Stateful Pod db-0 (IP: 10.233.65.21)"]
    ClientPod -.->|Direct TCP: 10.233.66.22| DB1["Stateful Pod db-1 (IP: 10.233.66.22)"]
    ClientPod -.->|Direct TCP: 10.233.67.23| DB2["Stateful Pod db-2 (IP: 10.233.67.23)"]
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None  # Headless!
  selector:
    app: database
  ports:
    - port: 5432
      targetPort: 5432
```

---

### 3. `NodePort`

* **How it works:** Kubernetes opens a high-range port (`30000–32767`) on **every node in the cluster**. Traffic sent to `<Any-Node-IP>:<NodePort>` is forwarded to the matching backend pods, even if the target pod resides on a different node.

#### Diagram: `NodePort` Traffic Flow

```mermaid
flowchart TD
    Client["External Client"]
    Client -->|Connects to Node 01: 18.138.78.218:31080| Node1["Worker Node 01 (18.138.78.218)"]
    Client -.->|Or connects to Node 02: 13.215.117.171:31080| Node2["Worker Node 02 (13.215.117.171)"]

    subgraph Node1["Worker Node 01"]
        NP1["Port 31080 (kube-proxy)"] -->|Local routing| PodA["App Pod A (10.233.64.8)"]
        NP1 -->|Cross-node CNI tunnel| PodB["App Pod B (10.233.65.9)"]
    end

    subgraph Node2["Worker Node 02"]
        NP2["Port 31080 (kube-proxy)"] --> PodB
    end
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 31080  # Optional (auto-assigned if omitted)
```

---

### 4. `LoadBalancer`

* **How it works:** Extends `NodePort` by instructing a cloud provider (AWS, GCP, Azure) or a bare-metal controller (MetalLB) to provision an external hardware/software load balancer that distributes traffic to the cluster's NodePorts.

#### Diagram: `LoadBalancer` Traffic Flow

```mermaid
flowchart TD
    User["Internet User"] -->|HTTPS 443 / HTTP 80| CloudLB["Cloud Load Balancer (AWS ALB/NLB, GCP LB)"]

    CloudLB -->|NodePort 31080| Node1["Worker Node 01"]
    CloudLB -->|NodePort 31080| Node2["Worker Node 02"]
    CloudLB -->|NodePort 31080| Node3["Worker Node 03"]

    Node1 --> Pod1["App Pod 1"]
    Node2 --> Pod2["App Pod 2"]
    Node3 --> Pod3["App Pod 3"]
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
```

---

### 5. `ExternalName`

* **How it works:** Does not define selectors or endpoints. Instead, it instructs internal CoreDNS to return a `CNAME` pointing to an external domain outside the Kubernetes cluster (such as an AWS RDS database or third-party API).

#### Diagram: `ExternalName` Resolution

```mermaid
flowchart LR
    AppPod["Internal App Pod"] -->|1. Queries 'db.default.svc.cluster.local'| DNS["CoreDNS"]
    DNS -->|2. Returns CNAME: 'postgres.production.aws.com'| AppPod
    AppPod -->|3. Connects directly across VPC / Internet| ExternalDB["External AWS RDS Postgres"]
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  type: ExternalName
  externalName: postgres.production.aws.com
```

---

# Part 2: Diagrams for Each `Pod.spec` Networking Mode

---

### 1. Standard CNI Pod Network (Default)

* **How it works:** The Container Network Interface (Calico, Flannel, Cilium) gives the pod its own **isolated network namespace** and a dedicated cluster-internal IP (`10.233.x.x`). The pod communicates with the host through a virtual ethernet (`veth`) pair.

#### Diagram: Standard CNI Isolation

```mermaid
flowchart TD
    subgraph HostVM["Worker Node (Host Stack: eth0 - 18.138.78.218)"]
        subgraph PodNamespace["Pod Network Namespace (Isolated)"]
            Container["Application Container (nginx)"]
            PodVeth["eth0 inside Pod (IP: 10.233.64.5)"]
            Container -->|Listens on port 80| PodVeth
        end

        HostVeth["vethXXXX on Host"]
        CNIRouter["CNI Bridge / Calico Virtual Router"]
        HostNIC["Host Physical/Cloud Interface (eth0: 18.138.78.218)"]

        PodVeth <--> HostVeth
        HostVeth <--> CNIRouter
        CNIRouter <--> HostNIC
    end
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: standard-app-pod
spec:
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
```

---

### 2. `hostNetwork: true`

* **How it works:** The pod **completely bypasses network isolation** and attaches directly to the **host node's network stack**. Its IP is literally the host node's IP. Ports opened by the container (e.g., `80`, `443`) are opened directly on the host VM's `eth0` interface.
* **Important:** You must use `dnsPolicy: ClusterFirstWithHostNet` so the pod can still resolve Kubernetes internal service names via CoreDNS.

#### Diagram: `hostNetwork: true` Architecture

```mermaid
flowchart TD
    ExternalClient["External Client / Internet"] -->|Direct to 18.138.78.218:80| HostNIC["Host Physical NIC (eth0: 18.138.78.218)"]

    subgraph HostVM["Worker Node (Host Network Namespace)"]
        HostNIC --> HostPort80["Host Port 80"]
        HostNIC --> HostPort443["Host Port 443"]

        subgraph HostNetPod["Pod with hostNetwork: true (NO Isolated Namespace)"]
            IngressContainer["NGINX Ingress Controller"]
            HostPort80 --- IngressContainer
            HostPort443 --- IngressContainer
        end
    end
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-ingress-pod
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet  # Enables internal CoreDNS resolution
  containers:
    - name: ingress-controller
      image: registry.k8s.io/ingress-nginx/controller:v1.13.3
      ports:
        - name: http
          containerPort: 80
        - name: https
          containerPort: 443
```

---

### 3. `hostPort` (Hybrid Mode)

* **How it works:** The pod retains its **isolated pod namespace and private overlay IP (`10.233.x.x`)**, but the CNI installs an `iptables` DNAT rule on the host node mapping a specific host port directly to the container port.

#### Diagram: `hostPort` Mapping

```mermaid
flowchart TD
    ExternalClient["External Client"] -->|Connects to Node IP: 18.138.78.218:8080| HostNIC["Host NIC (eth0: 18.138.78.218)"]

    subgraph HostVM["Worker Node"]
        HostNIC --> IPTables["Host iptables / CNI Portmap"]

        subgraph PodNamespace["Pod Network Namespace (Isolated IP: 10.233.64.9)"]
            Container["Proxy Container (Listens on port 80)"]
        end

        IPTables -->|NAT forwards Node:8080 -> Pod:80| Container
    end
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: edge-proxy-pod
spec:
  containers:
    - name: proxy
      image: envoyproxy/envoy
      ports:
        - containerPort: 80
          hostPort: 8080       # Accessible at <Node-IP>:8080
```

---

# Part 3: Comparison Matrix

| Feature | `ClusterIP` | `NodePort` | `LoadBalancer` | `hostNetwork: true` | `hostPort` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Config Layer** | `Service.spec.type` | `Service.spec.type` | `Service.spec.type` | `Pod.spec` | `Pod.spec.containers[].ports[]` |
| **IP Address** | Virtual Cluster IP | Node IPs | Cloud LB Public IP | Node IP directly | Isolated Pod IP |
| **Port Range** | Any port | `30000–32767` | Any (80, 443, etc.) | Standard (80, 443, etc.) | Any host port |
| **Requires Cloud LB?** | No | No | **Yes** | **No** | **No** |
| **Client IP Preserved?** | No (SNAT) | Only with `local` policy | Yes (Proxy Protocol/L4) | **Yes (Direct)** | Only with specific CNIs |
| **Performance / Overhead** | `kube-proxy` NAT | Double hop / NAT | Cloud LB + NodePort | **Zero NAT overhead** | CNI `iptables` NAT |
| **Port Conflict Risk** | None | None | None | **High** (1 pod per node per port) | **High** (1 pod per node per port) |

---

# Part 4: Real-World Ingress in Kubespray

When you deploy NGINX Ingress via Kubespray:
1. **DaemonSet with `hostNetwork: true`**: Ingress pods run on every worker node and bind directly to ports `80` and `443` of the host VM. External DNS (like `nginx.seang.shop`) points directly to your worker public IPs without needing a cloud load balancer.
2. **`Service.spec.type: LoadBalancer`**: Kubespray also generates a service that automatically assigns NodePorts (`31080` / `32725`) as a fallback routing mechanism.
