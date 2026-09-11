# Comprehensive Guide: Traefik Ingress Controller on Google Kubernetes Engine (GKE)

## 1. What is Traefik?

**Traefik** is an open-source, highly popular **Kubernetes Ingress Controller** and API Gateway that runs inside your Kubernetes cluster.

Using Traefik on GKE is an excellent alternative to default GKE Ingress, especially if you want features like:
- Automatic **Let's Encrypt SSL certificates** (via ACME / Cert-Manager)
- Advanced request routing rules and traffic splitting (Canary releases)
- Rich Middleware capabilities (Rate limiting, Basic Auth, Header manipulation)
- Built-in real-time web dashboard
- Cloud-agnostic deployment (works identically across GKE, AWS EKS, Azure AKS, and Bare Metal)

---

## 2. How Traefik Works on GKE

Unlike GKE Native Ingress (which creates a Google Cloud HTTP(S) Load Balancer outside your cluster), Traefik runs as **Pods inside your cluster**.

To route external traffic to Traefik, you expose Traefik itself with a single GCP Network Load Balancer (`type: LoadBalancer`). Traefik then terminates TLS and routes traffic internally to your application pods.

```
[ Client HTTPS Request ]
           │
           ▼
[ GCP L4 Network Load Balancer ]  ◄── Created by Traefik Service (type: LoadBalancer)
           │
           ▼
[ Traefik Pods in K8s ]          ◄── Terminates TLS (Let's Encrypt) & handles path/host routing
           │
           ▼
[ Your Application Pods ]
```

---

## 3. GKE Native Ingress vs. Traefik Ingress

| Feature | GKE Native Ingress (`gce`) | Traefik Ingress Controller |
| :--- | :--- | :--- |
| **SSL / TLS** | Google-Managed Certificates | Built-in Let's Encrypt (Cert-Manager / ACME) |
| **Where it runs** | Managed GCP Cloud Load Balancer | Inside K8s Cluster (as Pods) |
| **Cost** | Charged per GCP HTTP(S) Forwarding Rule | Standard K8s Pod compute + 1 L4 Network LB |
| **Middlewares** | Cloud Armor / BackendConfig | Traefik Middlewares (Rate Limit, Auth, Headers, Redirects) |
| **Dashboard** | GCP Console | Built-in Traefik Web UI |
| **Portability** | GCP Specific | Cloud-Agnostic |

---

## 4. Core Architecture & Building Blocks

Traefik relies on five core concepts to process traffic:

1. **EntryPoint**: The network port listening for incoming traffic (e.g., `web` on port 80, `websecure` on port 443).
2. **Router**: Inspects incoming request details (Host, Path, Headers) and connects an EntryPoint to a Service.
3. **Middleware**: Modifies requests or responses in transit (e.g., HTTPS redirect, authentication, rate limiting).
4. **Service**: Load balances traffic across backend K8s Pods.
5. **TLS / CertResolver**: Manages SSL/TLS termination and certificate issuance.

---

## 5. In-Depth CRD Reference & Real-World Scenarios

---

### 1. `IngressRoute` (HTTP/HTTPS Layer 7 Router)

#### Deep Explanation
`IngressRoute` is Traefik’s primary custom resource for Layer 7 HTTP and HTTPS routing. It supersedes standard Kubernetes `Ingress` objects by offering advanced matching rules (`Host`, `PathPrefix`, `Headers`, `Query`, `Methods`), inline Middleware chaining, priority ordering, and fine-grained TLS control per route.

#### Real-World Scenario: E-Commerce Microservice Platform
An online store uses a single domain `shop.company.com`. They need:
- Traffic to `/cart` routed to the **Cart Microservice**.
- Traffic to `/products` routed to the **Product Catalog Service**.
- HTTP automatically redirected to HTTPS.

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ecommerce-router
  namespace: production
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`shop.company.com`) && PathPrefix(`/cart`)
      kind: Rule
      services:
        - name: cart-service
          port: 8080
    - match: Host(`shop.company.com`) && PathPrefix(`/products`)
      kind: Rule
      services:
        - name: product-service
          port: 8080
  tls:
    secretName: shop-company-tls
```

---

### 2. `IngressRouteTCP` & `IngressRouteUDP` (Layer 4 Protocol Routers)

#### Deep Explanation
Standard Kubernetes Ingress only understands HTTP/HTTPS. `IngressRouteTCP` and `IngressRouteUDP` allow Traefik to route non-HTTP protocols directly at the transport layer (TCP/UDP). 
- `IngressRouteTCP` routes TCP streams (PostgreSQL, MySQL, Redis, MQTT, gRPC without HTTP framing) using TLS SNI (`HostSNI`) or wildcard TCP ports.
- `IngressRouteUDP` routes UDP streams (DNS resolvers, Syslog collectors, VoIP, gaming server traffic).

#### Real-World Scenario: Secure PostgreSQL Database Cluster Exposure
A company runs a PostgreSQL database cluster inside Kubernetes. Data Analysts need to connect securely from outside using DBeaver over port 5432 with TLS encryption matching SNI `db-prod.company.com`.

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: postgres-external-route
  namespace: database
spec:
  entryPoints:
    - postgres-port # Custom EntryPoint defined on port 5432
  routes:
    - match: HostSNI(`db-prod.company.com`)
      services:
        - name: postgresql-cluster-service
          port: 5432
  tls:
    secretName: db-tls-cert
```

---

### 3. `Middleware` (HTTP Interceptors & Pipeline Processing)

#### Deep Explanation
`Middleware` custom resources sit between the `IngressRoute` and the backend `Service`. They can modify incoming requests (add/remove headers, rewrite URIs, enforce auth, rate limit) or modify outgoing responses (add CORS headers, security headers, compress payloads).

#### Real-World Scenario: SaaS API Gateway Protection (Rate Limit + Forward Auth)
A SaaS company exposes a public REST API (`api.company.com`). Before any request reaches the internal backend:
1. Enforce a **Rate Limit** of 100 requests/minute per client IP to prevent DDoS.
2. Pass requests to an **OAuth2 Forward Auth Service** (Keycloak / Auth0) to validate JWT tokens.

```yaml
# 1. Rate Limit Middleware
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: api-rate-limit
  namespace: production
spec:
  rateLimit:
    average: 100
    burst: 20
---
# 2. Forward Auth Middleware
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: oauth2-forward-auth
  namespace: production
spec:
  forwardAuth:
    address: "http://oauth2-proxy.auth.svc.cluster.local:4180/"
    trustForwardHeader: true
    authResponseHeaders:
      - "X-Auth-User"
      - "X-Auth-Email"
```

---

### 4. `MiddlewareTCP` (Layer 4 Connection Filtering)

#### Deep Explanation
`MiddlewareTCP` operates directly on TCP socket connections before any application protocol handshake occurs. It currently provides `ipAllowList` capabilities to restrict connection origin at the network level.

#### Real-World Scenario: Restricting Internal Redis Access to Specific Office Subnets
An enterprise exposes a Redis cluster via TCP. Only requests originating from the corporate office IP (`203.0.113.50/32`) or internal VPN (`10.8.0.0/24`) should be allowed to form a TCP connection.

```yaml
apiVersion: traefik.io/v1alpha1
kind: MiddlewareTCP
metadata:
  name: redis-ip-whitelist
  namespace: production
spec:
  ipAllowList:
    sourceRange:
      - "203.0.113.50/32" # Corporate Office IP
      - "10.8.0.0/24"     # Internal VPN Subnet
```

---

### 5. `TraefikService` (Advanced Load Balancing, Canary & Traffic Mirroring)

#### Deep Explanation
`TraefikService` supersedes standard Kubernetes Service load balancing. Instead of simple equal round-robin between pods, `TraefikService` enables:
- **Weighted Round-Robin (Canary Releases)**: Send X% to v1 and Y% to v2.
- **Request Mirroring (Traffic Shadowing)**: Copy 100% of live production traffic and asynchronously send it to an experimental test service without affecting production response times or user experience.

#### Real-World Scenario: Zero-Downtime Payment Gateway Migration
A fintech app is upgrading `payment-service` from `v1` to `v2`. They want:
- **90%** of live checkout traffic sent to `payment-v1`.
- **10%** of live checkout traffic sent to `payment-v2`.
- **100%** of traffic mirrored to `payment-v3-experimental` for performance benchmarking without sending responses back to users.

```yaml
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: payment-canary-mirror-service
  namespace: payments
spec:
  mirroring:
    name: payment-weighted-backend  # Main backend handling real user traffic
    port: 80
    mirrors:
      - name: payment-v3-experimental # Shadow service receiving copied requests
        port: 80
        percent: 100
---
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: payment-weighted-backend
  namespace: payments
spec:
  weighted:
    services:
      - name: payment-v1-service
        port: 80
        weight: 90 # 90% of real users
      - name: payment-v2-service
        port: 80
        weight: 10 # 10% of real users
```

---

### 6. `TLSOption` (Cryptographic & Security Hardening)

#### Deep Explanation
`TLSOption` defines global or per-route SSL/TLS handshake security parameters. It allows security teams to enforce modern TLS protocol versions, select allowed cipher suites, enforce strict SNI host matching, and mandate client certificate verification (mTLS).

#### Real-World Scenario: Banking / Fintech PCI-DSS Compliance
A bank must meet strict PCI-DSS audit requirements:
- Completely disable legacy TLS 1.0, 1.1, and 1.2 (Force TLS 1.3 minimum).
- Only allow modern AEAD cipher suites.
- Drop connections immediately if the client SNI header doesn't match the SSL certificate (`sniStrict`).

```yaml
apiVersion: traefik.io/v1alpha1
kind: TLSOption
metadata:
  name: pci-dss-strict-tls
  namespace: banking
spec:
  minVersion: VersionTLS13
  maxVersion: VersionTLS13
  cipherSuites:
    - TLS_AES_128_GCM_SHA256
    - TLS_AES_256_GCM_SHA384
    - TLS_CHACHA20_POLY1305_SHA256
  sniStrict: true
```

---

### 7. `TLSStore` (Global Fallback Certificates & Wildcards)

#### Deep Explanation
When an incoming HTTPS request arrives, Traefik looks for a matching certificate in the target `IngressRoute`. If no specific certificate matches, Traefik falls back to the default certificate defined in `TLSStore`.

#### Real-World Scenario: SaaS Multi-Tenant Platform with Wildcard Domain
A multi-tenant SaaS provider hosts thousands of customer subdomains (`tenant1.mycompany.app`, `tenant2.mycompany.app`). Instead of creating a new SSL certificate for every tenant, a global wildcard SSL certificate (`*.mycompany.app`) is loaded into `TLSStore` as default.

```yaml
apiVersion: traefik.io/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: traefik-system # Must be named 'default' in traefik namespace
spec:
  defaultCertificate:
    secretName: wildcard-mycompany-app-tls # Secret containing *.mycompany.app cert
```

---

### 8. `ServersTransport` (Upstream mTLS & Backend Encryption)

#### Deep Explanation
While `IngressRoute` handles the connection between the *Client and Traefik*, `ServersTransport` controls the connection between *Traefik and your backend Pods*. It is used for **Zero-Trust / End-to-End Encryption**, custom Root CA validation, or skipping self-signed cert verification on internal services.

#### Real-World Scenario: HIPAA-Compliant Healthcare End-to-End Encryption
A healthcare application managing Electronic Health Records (EHR) requires **End-to-End Encryption** (traffic must be encrypted even *inside* the Kubernetes cluster network between Traefik and backend Pods).

Traefik uses `ServersTransport` to initiate an encrypted mTLS session to the backend pod using an internal Root CA.

```yaml
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: backend-internal-mtls
  namespace: healthcare
spec:
  serverName: ehr-backend.internal
  insecureSkipVerify: false
  rootCAsSecrets:
    - internal-ca-cert-secret # Secret containing internal Root CA to trust backend Pod certs
  certificatesSecrets:
    - client-certificate-secret # Traefik's client certificate to authenticate with backend Pod
```

---

## 6. Deep Dive: Traefik Authentication & `forwardAuth` (`oauth2-proxy`)

### Is `oauth2-proxy` built-in to Traefik?
**No.** `oauth2-proxy` is **NOT built-in to Traefik**. It is an independent, open-source project ([OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/)) deployed as a separate application inside your Kubernetes cluster.

### Understanding the Kubernetes Internal DNS Address
The URL used in the `forwardAuth` middleware:
`http://oauth2-proxy.auth.svc.cluster.local:4180/`

Is a standard **Kubernetes Internal DNS address** structured as follows:

| Address Segment | Meaning |
| :--- | :--- |
| **`oauth2-proxy`** | The name of the Kubernetes `Service`. |
| **`auth`** | The Kubernetes `Namespace` where `oauth2-proxy` is deployed. |
| **`svc.cluster.local`** | The default cluster-internal domain suffix for all K8s services. |
| **`4180`** | The default container port listening on the `oauth2-proxy` service. |

---

### How Traefik `forwardAuth` Request Lifecycle Works

Traefik's `forwardAuth` middleware acts as an **authentication delegator**. When a client makes a request to your app, Traefik pauses the request and verifies the client with the authentication provider.

```
 1. Client requests https://api.example.com/dashboard
                          │
                          ▼
 2. Traefik receives request & triggers 'forwardAuth' Middleware
                          │
                          ▼
 3. Traefik sends sub-request to OAuth2 Proxy:
    GET http://oauth2-proxy.auth.svc.cluster.local:4180/
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
[ If 200 OK from Auth ]    [ If 401/403 Unauthorized ]
            │                           │
            ▼                           ▼
 Traefik forwards request   Traefik blocks request &
 to backend App Pods        redirects client to SSO Login
 (attaches user headers:    (Google, GitHub, Keycloak,
  X-Auth-User, etc.)         Auth0, Azure AD / Entra ID)
```

---

### Comparison of Authentication Options in Traefik

#### Option A: Traefik Built-in Auth (No external deployment needed)
Best for simple internal apps, staging environments, or quick password locks.
- **`basicAuth`**: Standard HTTP Basic Authentication reading credentials from a Kubernetes Secret (`htpasswd`).
- **`digestAuth`**: Standard HTTP Digest Authentication.

#### Option B: External Auth via `forwardAuth` (Enterprise SSO)
Best for production enterprise apps requiring SSO login with Google Workspace, GitHub, Keycloak, Auth0, Okta, or Azure AD.
- Traefik delegates auth checks via `forwardAuth` to an external proxy (`oauth2-proxy`, Authelia, or Authentik).

---

## 7. Detailed Line-by-Line Breakdown of Traefik `.yaml` Files

### 1. `IngressRoute` (HTTP / HTTPS Routing)

```yaml
apiVersion: traefik.io/v1alpha1  # 1. API group and version for Traefik Custom Resources
kind: IngressRoute               # 2. Resource type: HTTP/HTTPS router
metadata:
  name: web-app-ingress          # 3. Unique name of this IngressRoute in K8s
  namespace: default             # 4. Namespace where this resource resides
spec:
  entryPoints:                   # 5. List of ports Traefik listens on for this route
    - web                        #    - Port 80 (HTTP)
    - websecure                  #    - Port 443 (HTTPS)
  routes:                        # 6. Array of routing rules (matching logic + target)
    - match: Host(`api.example.com`) && PathPrefix(`/v1`)  # 7. Rule matcher condition
      kind: Rule                 # 8. Type of route (Rule is standard for HTTP)
      priority: 10               # 9. (Optional) Priority integer if multiple rules overlap
      middlewares:               # 10. List of Middlewares executed in sequential order
        - name: rate-limit-middleware  # First middleware to run
        - name: auth-middleware        # Second middleware to run
      services:                  # 11. Backend targets to receive the traffic
        - name: api-backend-service    # Name of standard K8s Service
          port: 8080                   # Target port exposed on the K8s Service
          weight: 1                    # (Optional) Weight for load balancing between services
  tls:                           # 12. TLS / HTTPS configuration section
    secretName: example-com-tls-secret  # Standard K8s Secret containing tls.crt and tls.key
    certResolver: letsencrypt           # (Alternative) Auto-fetch SSL cert using Let's Encrypt
    options:                            # (Optional) Reference to a TLSOption CRD for cipher hardening
      name: strict-tls
```

---

## 8. Complete Request Lifecycle Summary

```
 1. Incoming Client Request (e.g. https://api.example.com/v1/users)
                          │
                          ▼
 2. EntryPoint: "websecure" (Port 443)
                          │
                          ▼
 3. TLSOption: Enforces TLS 1.3 & Cipher Suite check
                          │
                          ▼
 4. IngressRoute: Matches Host(`api.example.com`) && PathPrefix(`/v1`)
                          │
                          ▼
 5. Middleware #1: "rate-limit-middleware" (Checks request rate)
                          │
                          ▼
 6. Middleware #2: "auth-middleware" (Validates HTTP Basic Auth header or forwardAuth)
                          │
                          ▼
 7. TraefikService: "canary-app-service" (Splits traffic: 90% V1 / 10% V2)
                          │
                          ▼
 8. Target K8s Service: "api-backend-service:8080" -> Pod IP
```
