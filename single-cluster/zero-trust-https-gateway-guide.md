# 🛡️ Zero-Trust HTTPS Guide: Gateway API + Traefik + cert-manager + Cloudflare Tunnel

This guide documents the complete end-to-end architecture and manual step-by-step instructions for exposing Kubernetes internal monitoring dashboards (**Grafana** and **OpenSearch Dashboards**) securely over HTTPS using **Kubernetes Gateway API (`gateway.networking.k8s.io/v1`)**, **Traefik v3**, **cert-manager (DNS-01)**, and **Cloudflare Tunnel (`cloudflared`)**.

---

## 🌐 1. End-to-End Traffic Architecture

```mermaid
flowchart LR
    client["🌐 User Browser<br><code>https://grafana.seang.shop</code><br><code>https://opensearch.seang.shop</code>"] 
    -->|Public HTTPS :443| cfEdge["☁️ Cloudflare Edge<br><i>Universal Edge SSL<br>Mode: Full (Strict)</i>"]
    
    cfEdge -->|Encrypted WireGuard / QUIC Tunnel| cfd["🚇 cloudflared Pod<br><i>(Namespace: traefik)</i>"]
    
    cfd -->|Verified Strict TLS :443<br>SNI: seang.shop| traefikGW["🚦 Traefik Gateway<br><i>traefik-gateway-tls<br>(*.seang.shop Wildcard)</i>"]

    traefikGW -->|HTTPRoute: grafana.seang.shop| grafana["📊 prometheus-grafana:80<br><i>(Namespace: monitoring)</i>"]
    traefikGW -->|HTTPRoute: opensearch.seang.shop| opensearch["🔎 opensearch-dashboards:5601<br><i>(Namespace: opensearch)</i>"]
```

### 🔒 Architectural Decision: Why Zero-Trust (Option B)?

| Requirement / Hop | Standard Ingress / Tunnel Only | This Zero-Trust Architecture |
| :--- | :--- | :--- |
| **Public Browser TLS** | ✅ Yes (Managed by Cloudflare Edge) | ✅ Yes (Managed by Cloudflare Edge) |
| **Edge-to-Cluster Tunnel** | ✅ Encrypted wire (WireGuard/QUIC) | ✅ Encrypted wire (WireGuard/QUIC) |
| **Internal Cluster In-Transit TLS** | ⚪ Plain HTTP inside cluster network | ✅ **Strict cryptographically verified TLS** |
| **Cloudflare SSL Encryption Mode** | Flexible / Full (no verify) | **Full (Strict)** |
| **Inbound Open Ports Needed?** | ❌ None (Tunnel initiates outbound) | ❌ **None** (Zero inbound firewall rules) |
| **Public Port 80 for Let's Encrypt?**| ⚠️ Required for HTTP-01 challenges | ❌ **Not needed** (DNS-01 uses Cloudflare API) |
| **Direct Cluster / VPN Access** | ❌ Browser warning ("Not Secure") | ✅ **Valid green padlock** inside and outside |

---

## 📋 2. Step-by-Step Manual Setup

### Step 1: Create Cloudflare API Token (For cert-manager DNS-01)

cert-manager uses this API token to dynamically create and delete `_acme-challenge.seang.shop` TXT DNS records during Let's Encrypt certificate issuance.

1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Click your user icon at the top right > **My Profile** > **API Tokens**.
3. Click **Create Token** > find **Custom Token** at the bottom > click **Get started**.
4. Configure the token permissions:
   - **Token name**: `k8s-cert-manager-dns01`
   - **Permissions**:
     - `Zone` | `DNS` | `Edit`
     - `Zone` | `Zone` | `Read`
   - **Zone Resources**:
     - `Include` | `Specific zone` | `seang.shop`
   - **TTL**: Leave empty (tokens will not expire prematurely).
5. Click **Continue to summary**, review, and click **Create Token**.
6. **Copy the API Token immediately** and store it safely.

---

### Step 2: Set Up Cloudflare Tunnel (`cloudflared`)

Choose either **Option 2A (Dashboard-Managed)** or **Option 2B (CLI-Managed)**.

#### Option 2A: Dashboard-Managed Tunnel (Recommended if you have Cloudflare Zero Trust)

1. Open [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2. Navigate to **Networks** > **Tunnels** > Click **Create a tunnel**.
3. Select **Cloudflared** connector > click **Next**.
4. Name your tunnel (e.g. `k8s-monitoring-tunnel`) > click **Save tunnel**.
5. In the **Install and run a connector** step, look at the Docker/Kubernetes command:
   - Copy the token string from `--token <TUNNEL_TOKEN>`.
6. Click **Next** to proceed to the **Public Hostnames** tab.
7. Add the routes:

   **Route 1 (Grafana):**
   - **Public Hostname**: Subdomain: `grafana`, Domain: `seang.shop`
   - **Service**: Type: `HTTPS`, URL: `traefik.traefik.svc.cluster.local:443`
   - **Additional application settings** > **TLS**:
     - **Origin Server Name**: `seang.shop`

   **Route 2 (OpenSearch Dashboards):**
   - **Public Hostname**: Subdomain: `opensearch`, Domain: `seang.shop`
   - **Service**: Type: `HTTPS`, URL: `traefik.traefik.svc.cluster.local:443`
   - **Additional application settings** > **TLS**:
     - **Origin Server Name**: `seang.shop`

   *(Or simply create a single wildcard route `*.seang.shop` pointing to `HTTPS://traefik.traefik.svc.cluster.local:443` with Origin Server Name `seang.shop`)*.

---

#### Option 2B: CLI-Managed Tunnel (NO Credit Card / Billing Required)

If you do not want to enter any payment info into Cloudflare Zero Trust, use the CLI method:

1. **Install `cloudflared` on your local terminal / machine**:
   ```bash
   # Linux AMD64
   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i cloudflared.deb
   ```
2. **Authenticate with Cloudflare**:
   ```bash
   cloudflared tunnel login
   ```
   Open the browser URL, choose your domain `seang.shop`, and authorize. This downloads `~/.cloudflared/cert.pem`.
3. **Create the Tunnel**:
   ```bash
   cloudflared tunnel create k8s-monitoring-tunnel
   ```
   Save the output:
   - **Tunnel ID** (UUID e.g. `4b8b6e22-8c7e-41d1-92b7-a3f8db1e8a90`)
   - **Credentials file** (`~/.cloudflared/<TUNNEL_ID>.json`)
4. **Route DNS into the Tunnel**:
   ```bash
   cloudflared tunnel route dns k8s-monitoring-tunnel "*.seang.shop"
   cloudflared tunnel route dns k8s-monitoring-tunnel "seang.shop"
   ```

---

### Step 3: Set Cloudflare SSL/TLS to Full (Strict)

1. In the standard [Cloudflare Dashboard](https://dash.cloudflare.com/), select your domain `seang.shop`.
2. Go to **SSL/TLS** > **Overview**.
3. Select **Full (Strict)**.

> [!NOTE]
> Because cert-manager generates a real, trusted Let's Encrypt certificate inside Kubernetes and attaches it to Traefik, `cloudflared` can validate the origin certificate against public WebPKI roots without needing `noTLSVerify: true`.

---

## ⚙️ 3. How to Deploy via Ansible

All automation is pre-built into the Ansible repository. You only need to populate your values in **[`group_vars/all.yml`](file:///home/seang/kubernete-aws-gcp/single-cluster/group_vars/all.yml#L320-L370)**.

### 1. Fill in Variables in `single-cluster/group_vars/all.yml`

Open [`single-cluster/group_vars/all.yml`](file:///home/seang/kubernete-aws-gcp/single-cluster/group_vars/all.yml) and update Section 16:

```yaml
# ------------------------------------------------------------------------------
# 16. ROLE: GATEWAY API, CERT-MANAGER & CLOUDFLARE TUNNEL (`roles/gateway_tls`)
# ------------------------------------------------------------------------------
enable_gateway_tls: true

base_domain: "seang.shop"
grafana_domain: "grafana.seang.shop"
opensearch_domain: "opensearch.seang.shop"

# Step 1: Paste your Cloudflare API Token here
cloudflare_cluster_issuer_name: "letsencrypt-cloudflare"
cloudflare_api_token: "PASTE_YOUR_CLOUDFLARE_API_TOKEN_HERE"

# Step 2: Choose tunnel mode and paste token or credentials
cloudflare_tunnel_mode: "token"     # "token" (Dashboard) or "credentials" (CLI)

# If using mode: "token":
cloudflare_tunnel_token: "PASTE_YOUR_TUNNEL_TOKEN_HERE"

# If using mode: "credentials":
# cloudflare_tunnel_id: "PASTE_TUNNEL_UUID_HERE"
# cloudflare_tunnel_credentials_json: |
#   {"AccountTag":"...","TunnelSecret":"...","TunnelID":"..."}
```

### 2. Run the Playbook

```bash
cd ~/kubernete-aws-gcp/single-cluster
ansible-playbook -i inventory.ini site.yml
```

The playbook executes `gateway_tls` in **Stage 5 (Last Stage)**, provisioning the certificates, HTTPRoutes, and Cloudflare Tunnel pods, followed by automated verification (`verify.yml`).

---

## 📄 4. Raw Kubernetes Manifest Reference (Manual `kubectl` Alternative)

If you ever need to inspect or deploy these resources manually with `kubectl` without Ansible, here are the standalone manifests:

### 1. Cloudflare API Token Secret
```yaml
# cloudflare-api-token-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: "<YOUR_CLOUDFLARE_API_TOKEN>"
```

### 2. Let's Encrypt DNS-01 ClusterIssuer
```yaml
# cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cloudflare
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: pengseangsim210@gmail.com
    privateKeySecretRef:
      name: letsencrypt-cloudflare-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

### 3. Traefik Wildcard TLS Certificate
```yaml
# wildcard-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-wildcard-cert
  namespace: traefik
spec:
  secretName: traefik-gateway-tls
  issuerRef:
    name: letsencrypt-cloudflare
    kind: ClusterIssuer
  dnsNames:
    - "seang.shop"
    - "*.seang.shop"
```

### 4. Gateway API HTTPRoute for Grafana
```yaml
# grafana-httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana-httproute
  namespace: monitoring
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "grafana.seang.shop"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: prometheus-grafana
          port: 80
```

### 5. Gateway API HTTPRoute for Prometheus UI
```yaml
# prometheus-httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: prometheus-httproute
  namespace: monitoring
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "prometheus.seang.shop"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: prometheus-kube-prometheus-prometheus
          port: 9090
```

### 6. Gateway API HTTPRoute for OpenSearch Dashboards
```yaml
# opensearch-httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: opensearch-dashboards-httproute
  namespace: opensearch
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "opensearch.seang.shop"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: opensearch-dashboards
          port: 5601
```

### 6. Cloudflare Tunnel Deployment (Token Mode)
```yaml
# cloudflared-deployment.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-tunnel-token
  namespace: traefik
type: Opaque
stringData:
  token: "<YOUR_TUNNEL_TOKEN>"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: traefik
  labels:
    app: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args:
            - tunnel
            - --metrics
            - 0.0.0.0:2000
            - --no-autoupdate
            - run
            - --token
            - $(TUNNEL_TOKEN)
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflare-tunnel-token
                  key: token
          livenessProbe:
            httpGet:
              path: /ready
              port: 2000
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

---

## 🔍 5. Verification & Troubleshooting Commands

### 1. Check Certificate Status
```bash
# Check if Certificate is Ready: True
kubectl get certificate -n traefik

# Inspect cert-manager events and orders
kubectl describe certificate traefik-wildcard-cert -n traefik
kubectl get challenges -A
kubectl get orders -A
```

### 2. Check Gateway API HTTPRoutes
```bash
# Verify both routes are programmed and attached to traefik-gateway
kubectl get httproute -A
kubectl describe httproute -n monitoring grafana-httproute
kubectl describe httproute -n opensearch opensearch-dashboards-httproute
```

### 3. Check Cloudflare Tunnel Pods
```bash
# Check pod health
kubectl get pods -n traefik -l app=cloudflared

# Inspect tunnel connection logs
kubectl logs -n traefik -l app=cloudflared -f
```

### 4. Common Troubleshooting Scenarios

| Symptom | Probable Cause | Quick Fix |
| :--- | :--- | :--- |
| `x509: certificate is valid for ..., not traefik.traefik.svc` | `cloudflared` connecting to internal K8s service name without SNI | In Cloudflare Zero Trust public hostname settings (or `config.yaml`), set **Origin Server Name** to `seang.shop`. |
| DNS-01 Challenge stuck in `Pending` | Cloudflare API token permissions insufficient | Ensure token has **Zone > DNS > Edit** and **Zone > Zone > Read** permissions specifically scoped to `seang.shop`. |
| HTTPRoute returns `503 Service Unavailable` | Backend Pod not ready or service name mismatch | Check `kubectl get svc -n monitoring prometheus-grafana` and `kubectl get svc -n opensearch opensearch-dashboards`. |
| HTTPRoute returns `404 Not Found` | Domain header mismatch or listener namespace policy | Ensure `traefik-gateway` has `allowedRoutes.namespaces.from: All` (already configured in this setup). |

---

## 🧠 6. Architectural Deep Dive: Gateway API vs. Traefik CRDs & Middleware Integration

### 1. Specification vs. Engine: How They Relate

An important distinction when designing Kubernetes ingress is that **Gateway API and Traefik are not competing alternatives—they work together**:

* **Kubernetes Gateway API (`gateway.networking.k8s.io`)** is the **Specification (Rulebook / Interface)** created by Kubernetes SIG-Network. It defines standard schemas (`Gateway`, `HTTPRoute`, `TCPRoute`, `TLSRoute`). It cannot route network packets by itself.
* **Traefik** is the **Proxy Engine (The Worker)**. Traefik is the Go application that executes routing rules, terminates TLS, and forwards bytes. In this cluster, **Traefik is the controller implementing the Gateway API specification**.

Traefik also maintains its own proprietary CRDs (`traefik.io/v1alpha1`) created before Gateway API matured.

```
┌────────────────────────────────────────────────────────┐
│              Kubernetes Gateway API (v1)               │
│    (Standard Interface: HTTPRoute, TCPRoute, etc.)     │
└──────────────────────────┬─────────────────────────────┘
                           │ implemented by
┌──────────────────────────▼─────────────────────────────┐
│                 Traefik Proxy Engine                   │
│        (Data Plane: routes packets, manages TLS)       │
└──────────────────────────▲─────────────────────────────┘
                           │ also supports
┌──────────────────────────┴─────────────────────────────┐
│               Traefik Proprietary CRDs                 │
│         (IngressRoute, IngressRouteTCP, Middleware)    │
└────────────────────────────────────────────────────────┘
```

---

### 2. Side-by-Side Comparison

| Feature | Kubernetes Gateway API (`HTTPRoute`, `TCPRoute`) | Traefik Proprietary CRDs (`IngressRoute`, `IngressRouteTCP`) |
| :--- | :--- | :--- |
| **Origin** | Official Kubernetes SIG-Network standard | Traefik-proprietary Custom Resource Definition |
| **Portability** | **100% Portable** across controllers (Traefik, Envoy, Istio, Cilium) | **Locked to Traefik** (requires complete rewrite if changing ingress) |
| **Resource Kinds** | `HTTPRoute`, `GRPCRoute`, `TLSRoute`, `TCPRoute`, `UDPRoute` | `IngressRoute`, `IngressRouteTCP`, `IngressRouteUDP` |
| **Traefik Middleware Support** | Integrated via `ExtensionRef` filter | Native via `spec.routes.middlewares` |
| **Industry Direction** | **The official standard for Kubernetes networking (v1 GA)** | Maintained for backward compatibility and Traefik-specific features |

#### Resource Mapping
```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│ Kubernetes Gateway API (Standard)│       │ Traefik Proprietary CRDs        │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ HTTPRoute                       │ <===> │ IngressRoute (HTTP/HTTPS)       │
│ TCPRoute                        │ <===> │ IngressRouteTCP (Raw TCP)       │
│ UDPRoute                        │ <===> │ IngressRouteUDP (Raw UDP)       │
│ TLSRoute (SNI Passthrough)      │ <===> │ IngressRouteTCP (with tls: true)│
└─────────────────────────────────┘       └─────────────────────────────────┘
```

---

### 3. How to Choose Which One to Use

```mermaid
flowchart TD
    start{"What are you routing?"} --> proto{"HTTP/Web UI or TCP/UDP?"}

    proto -->|HTTP / Web UIs<br>Grafana, OpenSearch, etc.| needMiddleware{"Do you require Traefik-specific Middlewares?<br>e.g. Traefik ForwardAuth, Plugin Marketplace"}
    
    needMiddleware -->|No - Standard routing & TLS| useHTTPRoute["✅ Use Gateway API: HTTPRoute<br>(Recommended & Future-Proof)"]
    needMiddleware -->|Yes - Deep Traefik features| useIngressRoute["Use Traefik: IngressRoute<br>(Or attach Middleware to HTTPRoute via ExtensionRef)"]

    proto -->|Raw TCP / UDP<br>e.g. Kafka, Database, DNS| portability{"Is multi-ingress controller portability important?"}
    
    portability -->|Yes| useTCPRoute["✅ Use Gateway API: TCPRoute / UDPRoute"]
    portability -->|No - Traefik only| useIngressRouteTCP["Use Traefik: IngressRouteTCP / UDP"]
```

#### Choose Kubernetes Gateway API (`HTTPRoute`, `TCPRoute`) if:
1. **Future-Proofing**: Gateway API is the official successor to Kubernetes `Ingress`.
2. **Zero Vendor Lock-In**: Routes continue functioning if you migrate to Envoy Gateway, Istio, or Cilium.
3. **Standard Dashboard Routing**: Host header matching, path routing, and TLS termination for Grafana, Prometheus, OpenSearch, and Jaeger are fully native.

#### Choose Traefik Custom CRDs (`IngressRoute`, `IngressRouteTCP`) only if:
1. You depend heavily on Traefik-specific features like ForwardAuth, CircuitBreakers, or custom Go plugins.
2. You need complex TCP SNI passthrough rules relying specifically on Traefik `TLSOption` CRDs (e.g. custom mTLS cipher suites).

---

### 4. Feature Coverage Matrix

| Feature | Gateway API (`HTTPRoute`) | Traefik CRD (`IngressRoute`) |
| :--- | :---: | :---: |
| **Host & Path Matching** (Prefix, Exact, Regex) | ✅ **Native** | ✅ Native |
| **Header & Query Param Matching** | ✅ **Native** | ✅ Native |
| **Header Manipulation** (Add, Set, Remove) | ✅ **Native** (`RequestHeaderModifier`) | ✅ via `Middleware` |
| **URL Rewrites & Path Prefixes** | ✅ **Native** (`URLRewrite`) | ✅ via `Middleware` |
| **HTTP to HTTPS Redirects** | ✅ **Native** (`RequestRedirect`) | ✅ via `Middleware` |
| **Traffic Splitting / Canary Deployments** | ✅ **Native** (via `weight`) | ✅ Native |
| **Traffic Mirroring / Shadowing** | ✅ **Native** (`RequestMirror`) | ✅ Native |
| **Multi-Namespace Routing** | ✅ **Native** (`parentRefs`) | ⚠️ Requires special Traefik flags |
| **gRPC Native Routing** | ✅ **Native** (`GRPCRoute`) | ⚠️ Configured as HTTP2 |
| **Rate Limiting** | 🔌 **Supported via `ExtensionRef`** | ✅ Built-in Traefik `Middleware` |
| **Basic Auth / Digest Auth** | 🔌 **Supported via `ExtensionRef`** | ✅ Built-in Traefik `Middleware` |
| **Forward Authentication (SSO / OAuth2)** | 🔌 **Supported via `ExtensionRef`** | ✅ Built-in Traefik `Middleware` |
| **Traefik Plugin Marketplace (Custom Go Plugins)** | 🔌 **Supported via `ExtensionRef`** | ✅ Built-in |

---

### 5. Integrating Traefik Middlewares into Gateway API (`ExtensionRef`)

You do **not** have to abandon Gateway API to use Traefik's advanced features. The Gateway API specification provides a native extension mechanism called **`ExtensionRef`** that allows standard `HTTPRoute` rules to invoke Traefik's proprietary `Middleware` engine.

```mermaid
flowchart LR
    route["Standard Gateway API<br><code>kind: HTTPRoute</code><br><i>filters.type: ExtensionRef</i>"]
    -->|References| mw["Traefik CRD<br><code>kind: Middleware</code><br><i>(RateLimit / Auth / SSO / Plugin)</i>"]
    -->|Executed by| engine["🚦 Traefik Proxy Engine"]
```

#### A. Rate Limiting Example

**Step 1: Declare the Traefik RateLimit Middleware**
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: limit-requests
  namespace: monitoring
spec:
  rateLimit:
    average: 100   # 100 requests per second
    burst: 50
```

**Step 2: Attach it to the standard `HTTPRoute`**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana-httproute
  namespace: monitoring
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "grafana.seang.shop"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: limit-requests
      backendRefs:
        - name: prometheus-grafana
          port: 80
```

#### B. Basic Authentication Example

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ui-users-secret
  namespace: monitoring
type: Opaque
stringData:
  users: |
    admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basic-auth-middleware
  namespace: monitoring
spec:
  basicAuth:
    secret: ui-users-secret
---
# In HTTPRoute rules.filters:
filters:
  - type: ExtensionRef
    extensionRef:
      group: traefik.io
      kind: Middleware
      name: basic-auth-middleware
```

#### C. Forward Authentication (SSO / OAuth2 with Authelia or Keycloak)

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: sso-forward-auth
  namespace: monitoring
spec:
  forwardAuth:
    address: "http://authelia.auth.svc.cluster.local:9091/api/verify?rd=https://auth.seang.shop"
    trustForwardHeader: true
    authResponseHeaders:
      - "Remote-User"
      - "Remote-Groups"
---
# In HTTPRoute rules.filters:
filters:
  - type: ExtensionRef
    extensionRef:
      group: traefik.io
      kind: Middleware
      name: sso-forward-auth
```

#### D. Traefik Marketplace Custom Plugins

Traefik plugins (from [plugins.traefik.io](https://plugins.traefik.io)) are configured as Middlewares and attached using the exact same `ExtensionRef` syntax:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: geo-block
  namespace: monitoring
spec:
  plugin:
    geoblock:
      allowLocal: true
      countries:
        - US
        - KH
---
# In HTTPRoute rules.filters:
filters:
  - type: ExtensionRef
    extensionRef:
      group: traefik.io
      kind: Middleware
      name: geo-block
```

---

### 6. Edge Alternative: Cloudflare Zero Trust Access

Because this cluster is already fronted by **Cloudflare Tunnel**, you have an even simpler alternative to in-cluster authentication and rate limiting:

* **Cloudflare Access (Zero Trust)**: You can enforce Google, GitHub, or Okta SSO logins and rate limiting directly at **Cloudflare's Anycast Edge** before requests ever enter the tunnel or touch the cluster.
* **Benefits**: No in-cluster authentication pods (like Authelia/Keycloak) or secrets to manage, and unauthorized requests are blocked before consuming any cluster bandwidth or compute resources.

