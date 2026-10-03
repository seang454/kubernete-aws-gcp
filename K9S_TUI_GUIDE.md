# K9s Terminal UI (TUI) - Complete Reference Manual & Advanced Guide

K9s is an enterprise-grade terminal-based UI designed to interact with and manage Kubernetes clusters. It accelerates cluster observation, live debugging, YAML modifications, log streaming, port-forwarding, security audits, and workload lifecycle operations without the friction of lengthy `kubectl` commands.

---

## Table of Contents

1. [Launching K9s & CLI Flags](#1-launching-k9s--cli-flags)
2. [Interface Anatomy & Core Mental Model](#2-interface-anatomy--core-mental-model)
3. [Resource Navigation: Colon (`:`) Commands](#3-resource-navigation-colon--commands)
4. [Managing Pods: Logs, Shells, and Debugging](#4-managing-pods-logs-shells-and-debugging)
5. [Managing Workloads: Deployments, StatefulSets, DaemonSets](#5-managing-workloads-deployments-statefulsets-daemonsets)
6. [Managing Nodes: Cordon, Uncordon, Drain & Root Host Shell](#6-managing-nodes-cordon-uncordon-drain--root-host-shell)
7. [Secrets, ConfigMaps, and Storage](#7-secrets-configmaps-and-storage)
8. [Advanced Filtering, Sorting, and Namespaces](#8-advanced-filtering-sorting-and-namespaces)
9. [Multi-Resource Batch Operations (Mark Mode)](#9-multi-resource-batch-operations-mark-mode)
10. [Cluster Sanitizer & Health Auditing: Popeye (`:popeye`)](#10-cluster-sanitizer--health-auditing-popeye-popeye)
11. [Live HTTP Benchmarking (`Shift-B`)](#11-live-http-benchmarking-shift-b)
12. [Native Helm Release Management (`:helm`)](#12-native-helm-release-management-helm)
13. [RBAC Authorization & "Can-I" Auditing (`:can`)](#13-rbac-authorization--can-i-auditing-can)
14. [Advanced Visualizations: Pulses & X-Ray](#14-advanced-visualizations-pulses--x-ray)
15. [Persistent Port-Forward Dashboard (`:pf`)](#15-persistent-port-forward-dashboard-pf)
16. [Screen Dumps & Exporting Table Snapshots (`Ctrl-E`)](#16-screen-dumps--exporting-table-snapshots-ctrl-e)
17. [Custom Plugin Ecosystem (`plugins.yaml`)](#17-custom-plugin-ecosystem-pluginsyaml)
18. [Custom Views & Custom JSONPath Columns (`views.yaml`)](#18-custom-views--custom-jsonpath-columns-viewsyaml)
19. [Custom Hotkeys (`hotkeys.yaml`) & Aliases (`aliases.yaml`)](#19-custom-hotkeys-hotkeysyaml--aliases-aliasesyaml)
20. [Terminal Themes & Skins (`skins/`)](#20-terminal-themes--skins-skins)
21. [Deep Configuration Reference (`config.yaml`)](#21-deep-configuration-reference-configyaml)
22. [Troubleshooting & Environment Variables](#22-troubleshooting--environment-variables)
23. [Expert-Level Hidden Mechanics & Edge Cases](#23-expert-level-hidden-mechanics--edge-cases)
24. [Master Quick-Reference Cheat Sheet](#24-master-quick-reference-cheat-sheet)

---

## 1. Launching K9s & CLI Flags

Start K9s with specific operational contexts, namespaces, or safety modes:

```bash
# Launch with current kubeconfig context & default namespace
k9s

# Launch directly into a specific namespace
k9s -n production

# Launch viewing all namespaces
k9s -A
# or
k9s --all-namespaces

# Target a specific cluster context from your kubeconfig
k9s --context gke_my-project_us-central1_prod

# Production safety mode: Read-Only (disables delete, edit, shell, scale)
k9s --readonly

# Set UI refresh polling rate (default is 2s)
k9s --refresh 1

# Launch directly into a specific view
k9s -c pod
k9s -c deploy
k9s -c helm

# Hide navigation breadcrumbs for compact terminal screens
k9s --crumbs-less

# Launch in headless mode for scripts or dumps
k9s --headless

# Multi-Kubeconfig Concatenation (merge AWS, GCP, on-prem configs in-memory)
KUBECONFIG=~/.kube/eks.yaml:~/.kube/gke.yaml:~/.kube/onprem.yaml k9s
```

---

## 2. Interface Anatomy & Core Mental Model

K9s follows Vim-style navigation principles:

* **Header Area**: Displays cluster context, Kubernetes version, CPU/Memory telemetry gauges, active namespace, and resource counts.
* **Main Table Area**: Real-time table of active resources with status indicators.
* **Menu Bar (Top-Right / Bottom)**: Dynamically displays available keyboard shortcuts for the resource currently in focus.
* **Command Bar**: Input buffer triggered when typing `:` (commands), `/` (search/filter), or `?` (help).

### Core Global Hotkeys

| Key | Action | Description |
| :--- | :--- | :--- |
| **`?`** | **Help** | Opens modal displaying all valid hotkeys for the current screen |
| **`:`** | **Command Mode** | Switch resource views (e.g., `:pod`, `:deploy`, `:helm`) |
| **`/`** | **Filter Mode** | Filter table entries using regex or label selectors |
| **`Esc`** | **Escape / Back** | Clear active filter, dismiss modal, or navigate to previous screen |
| **`j` / `k`** or **`↓` / `↑`** | **Navigate** | Move row selection down or up |
| **`Enter`** | **Drill Down** | Inspect children (Pods $\rightarrow$ Containers, Deployments $\rightarrow$ Pods) |
| **`Ctrl-C`** or `:q` | **Quit** | Exit K9s |

---

## 3. Resource Navigation: Colon (`:`) Commands

Press `:` in normal mode, type the alias, and hit `Enter`:

| Command | Resource | Purpose |
| :--- | :--- | :--- |
| `:pod` or `:po` | Pods | Pod lifecycle, containers, logs, exec |
| `:deploy` or `:dp` | Deployments | Scale, rollout restarts, edits |
| `:svc` | Services | Service endpoints, cluster IPs, NodePorts |
| `:ing` | Ingresses | Host rules, path routes, TLS cert associations |
| `:cm` | ConfigMaps | Configuration keys and data |
| `:sec` | Secrets | Secret keys and decoded payloads (`x`) |
| `:ns` | Namespaces | Switch or manage cluster namespaces |
| `:node` or `:no` | Nodes | Node capacity, resource allocation, cordon/drain |
| `:pvc` / `:pv` | Storage | Persistent Volume Claims & Volumes |
| `:sts` | StatefulSets | Stateful workload sets and storage templates |
| `:ds` | DaemonSets | Per-node daemon workloads |
| `:cj` / `:job` | Jobs | CronJobs and batch Jobs |
| `:events` or `:ev` | Cluster Events | Real-time stream of all warnings, probe failures, and crashes |
| `:ctx` | Contexts | Switch between Kubernetes clusters instantly |
| `:helm` | Helm Releases | Manage deployed Helm charts, revisions, and rollbacks |
| `:crds` or `:crd` | CRDs | Explore Custom Resource Definitions & instances |
| `:can` | RBAC Check | Interactive `can-i` permission auditor |
| `:rb` / `:crb` | RoleBindings | Role and ClusterRole binding inspection |
| `:popeye` or `:pop` | Popeye Sanitizer | Cluster health & configuration linter |
| `:pulses` | Pulses Dashboard | Bird's-eye cluster health dashboard |
| `:xray <res>` | X-Ray Graph | Tree view mapping dependencies (e.g. `:xray deploy`) |
| `:pf` | Port-Forwards | Central manager for all active background port forwards |

---

## 4. Managing Pods: Logs, Shells, and Debugging

### Highlight Actions on Pods

| Hotkey | Action | Description |
| :--- | :--- | :--- |
| **`l`** | **Logs** | Stream live logs for container(s) |
| **`s`** | **Shell** | Exec interactive shell (`sh`/`bash`) inside container |
| **`d`** | **Describe** | Formatted describe output (`kubectl describe pod`) |
| **`y`** | **YAML** | View raw YAML definition (automatically cleans noisy `managedFields`) |
| **`e`** | **Edit** | Open specification directly in `$EDITOR` (`kubectl edit`) |
| **`Shift-F`** | **Port-Forward** | Establish local background port forwarding |
| **`Ctrl-D`** | **Delete** | Delete selected pod (with confirmation) |

### Advanced Log Viewer Hotkeys (`l`)

* **`0` - `9`**: Switch between containers in multi-container pods.
* **`p`**: Toggle **Previous Logs** (critical for debugging crashed/terminated containers in `CrashLoopBackOff`).
* **`a`**: Toggle **Auto-scroll** / live tailing.
* **`t`**: Toggle **Timestamps** on or off.
* **`w`**: Toggle line wrap.
* **`/`**: Search / filter lines inside the log output.
* **`s`**: Save log stream to a local text file on your workstation.
* **`c`**: Copy visible log content to clipboard.

### Debugging Distroless / Scratch Containers (Ephemeral Containers)
For modern containers that do not have `/bin/sh` or `/bin/bash`:
* K9s supports launching **Ephemeral Debug Containers** attached to running pods.
* You can configure a standard debug image (e.g. `nicolaka/netshoot` or `busybox`) in `config.yaml` to troubleshoot network and file issues on distroless workloads.

---

## 5. Managing Workloads: Deployments, StatefulSets, DaemonSets

When highlighting a Deployment (`:deploy`), StatefulSet (`:sts`), or DaemonSet (`:ds`):

* **`s` (Scale)**: Interactively adjust replica counts up or down.
* **`r` (Restart)**: Triggers an immediate zero-downtime rolling update (`kubectl rollout restart`).
* **`Enter`**: View the exact child Pods generated by this workload.
* **`d`**: View workload events, rollout status, and condition flags.
* **`e`**: Edit the specification live in your terminal editor.

---

## 6. Managing Nodes: Cordon, Uncordon, Drain & Root Host Shell

When in the Node view (`:node`):

* **`s` (Node Host Shell)**:
  * **Power Feature**: Automatically schedules a temporary privileged pod onto the target node and drops you into a **root host shell**.
  * Allows direct inspection of host disk space, systemd services (`kubelet`, `containerd`), and host networking without needing cloud SSH access.
* **`c` (Cordon)**: Marks node as unschedulable (prevents new pods from landing on it).
* **`u` (Uncordon)**: Marks node as schedulable again.
* **`d` (Drain)**: Evicts running workloads safely, honoring PodDisruptionBudgets.
* **`Shift-C`**: Sort nodes by CPU usage/allocation percentage.
* **`Shift-M`**: Sort nodes by Memory allocation percentage.
* **`y`**: Inspect Node capacity, allocatable resources, taints, and labels.

---

## 7. Secrets, ConfigMaps, and Storage

### Secrets (`:sec`)
* Highlight a Secret and press **`Enter`** to inspect keys and values.
* Press **`x`**: Decodes base64 secret values directly in the UI.

### ConfigMaps (`:cm`)
* Press **`Enter`** to inspect configuration key-value pairs or mounted configuration files.

### Storage (`:pvc` / `:pv`)
* Inspect mount points, access modes (`ReadWriteOnce`, `ReadWriteMany`), capacity, and binding states (`Bound`, `Lost`, `Pending`).

---

## 8. Advanced Filtering, Sorting, and Namespaces

### Namespace Switching
* **`0`**: View resources across **all namespaces** simultaneously.
* **`:ns`**: Opens namespace list. Highlight a namespace and hit `Enter` to switch into it.
* **`1` through `9`**: Quick-jump to favorite namespaces (pinned in `config.yaml`).

### Search & Filtering Syntax (`/`)
Press **`/`** on any table view:

| Syntax Pattern | Example | Purpose |
| :--- | :--- | :--- |
| **Substring** | `/api` | Matches rows containing "api" |
| **Label Selector** | `/-l app=backend,env=prod` | Filters strictly by Kubernetes label selectors |
| **Inverse Regex** | `/!canary` | Excludes any row containing "canary" |
| **Regex Alternation**| `/nginx\|redis` | Matches either "nginx" or "redis" |
| **Status Filter** | `/CrashLoop` or `/Pending` | Isolates pods in failed or non-running states |

### Table Sorting Shortcuts
* **`Shift-A`**: Sort by Age
* **`Shift-C`**: Sort by CPU Usage
* **`Shift-M`**: Sort by Memory Usage
* **`Shift-S`**: Sort by Status
* **`Shift-N`**: Sort by Name

---

## 9. Multi-Resource Batch Operations (Mark Mode)

Perform batch actions across multiple items without repetitive clicks:

1. Use **`Ctrl-Space`** (or **Spacebar**) on highlighted rows to **mark** them.
2. Marked resources display a distinct visual highlight and an asterisk `*`.
3. Execute batch commands:
   * **`Ctrl-D`**: Batch delete all marked pods/workloads simultaneously.
   * **`l`**: Aggregate logs from all marked pods into a unified stream.

---

## 10. Cluster Sanitizer & Health Auditing: Popeye (`:popeye`)

K9s integrates **Popeye**, an autonomous cluster sanitizer that inspects your live cluster for misconfigurations, security oversights, and wasted capacity.

* **Command**: `:popeye` or `:pop`
* **What it audits**:
  * Pods/Containers missing CPU & Memory limits or requests.
  * Unused ConfigMaps, Secrets, and Persistent Volume Claims.
  * Deprecated Kubernetes API versions in use.
  * Container port mismatches between Pod specs and Services.
  * Over-permissioned RBAC roles.
* **Grading**: Produces a report card grading your cluster from **A (Healthy) to F (Critical)** with remediation hints. Press `Enter` on any flagged resource to see how to resolve it.

---

## 11. Live HTTP Benchmarking (`Shift-B`)

K9s has an integrated benchmarking engine powered by `hey` or `vegeta`:

1. Highlight any Pod or Service that has an active port-forward.
2. Press **`Shift-B`**.
3. Fill in benchmark parameters in the modal:
   * Number of requests
   * Concurrency level
   * HTTP Method (GET, POST, etc.)
   * Request Payload (optional)
4. Press `OK` to run.
5. K9s streams real-time latency percentiles (P50, P90, P99), requests per second, and status code breakdowns.

---

## 12. Native Helm Release Management (`:helm`)

Manage Helm charts without leaving K9s:

* **Command**: `:helm`
* View release names, revisions, chart versions, and status (`deployed`, `failed`).
* **`Enter`**: Inspect installed Helm release manifests, user-supplied `values.yaml`, and computed notes.
* **`h`**: View historical revisions.
* **`Ctrl-D`**: Uninstall a Helm release cleanly.

---

## 13. RBAC Authorization & "Can-I" Auditing (`:can`)

Quickly audit authorization rights without executing manual `kubectl auth can-i`:

* **Command**: `:can <verb> <resource>` or `:can`
  * Example: `:can create deployments`
  * Example: `:can delete pods`
* Test permissions for your current user, target service account, or role.
* **`:rb`** (RoleBindings) and **`:crb`** (ClusterRoleBindings):
  * Drill into subjects, mapped roles, and granular API groups granted to a ServiceAccount.

---

## 14. Advanced Visualizations: Pulses & X-Ray

### Pulses (`:pulses`)
A real-time cockpit providing a high-level visual health summary of:
* Pod states (Running, Pending, Error, CrashLoop)
* Deployment & ReplicaSet health
* Node resource saturation

### X-Ray (`:xray <resource>`)
Generates an interactive tree view mapping relationships between Kubernetes components:

```text
:xray deploy
:xray pod
:xray svc
:xray node
```

*Example Dependency Tree*:
`Service -> Deployment -> ReplicaSet -> Pods -> Containers -> ConfigMaps & PVCs`

---

## 15. Persistent Port-Forward Dashboard (`:pf`)

* Standard `kubectl port-forward` commands terminate if the shell terminates.
* In K9s, port-forwards initiated via **`Shift-F`** persist in the background managed by the K9s process.
* **Zero-Port Auto-Allocation**: Setting the local port to `0` or leaving it empty assigns an unused ephemeral port automatically to prevent port conflicts across multiple replicas.
* **Command**: `:pf`
  * View active forward addresses, target container ports, local ports, and traffic status.
  * Terminate single or all active forwards with **`Ctrl-D`**.

---

## 16. Screen Dumps & Exporting Table Snapshots (`Ctrl-E`)

Export the current view table or screen data directly for documentation, incident tickets, or sharing on Slack:

* Press **`Ctrl-E`** anywhere in K9s.
* K9s exports the full rendered data to a timestamped file located at:
  `~/.local/state/k9s/screen-dumps/` (or `~/.k9s/screen-dumps/`).

---

## 17. Custom Plugin Ecosystem (`plugins.yaml`)

Map any CLI tool or custom shell script to a hotkey inside K9s views.

Configuration file location: `~/.config/k9s/plugins.yaml` (or `~/.k9s/plugins.yaml`).  
*Note: K9s automatically hot-reloads plugin configurations upon saving.*

### Full Reference of Runtime Variables Injected into Plugins

| Variable | Injected Value |
| :--- | :--- |
| **`$NAMESPACE`** | Currently highlighted resource's namespace |
| **`$NAME`** | Currently highlighted resource's name |
| **`$CONTEXT`** | Currently active cluster context |
| **`$CLUSTER`** | Active cluster name from kubeconfig |
| **`$USER`** | Active user identity |
| **`$RESOURCE_NAME`** | Target resource kind (e.g. `pods`, `deployments`) |
| **`$RESOURCE_GROUP`**| API group (e.g. `apps`, `networking.k8s.io`) |
| **`$RESOURCE_VERSION`**| API version (e.g. `v1`, `v1beta1`) |
| **`$FILTER`** | Currently active filter query string |
| **`$COL-<HEADER>`** | Extracts exact value from any visible table column (e.g. `$COL-IP`, `$COL-NODE`) |

### Example 1: View Clean YAML without system metadata (`kubectl-neat`)
```yaml
plugins:
  neat-yaml:
    shortCut: Shift-N
    confirm: false
    description: "Neat YAML"
    scopes:
      - all
    command: kubectl
    background: false
    args:
      - neat
      - -n
      - $NAMESPACE
      - --
      - get
      - $RESOURCE_NAME
      - $NAME
      - -o
      - yaml
```

### Example 2: Multi-Pod Log Streaming with `stern`
```yaml
plugins:
  stern-tail:
    shortCut: Shift-L
    confirm: false
    description: "Stern Logs"
    scopes:
      - pods
    command: stern
    background: false
    args:
      - --namespace
      - $NAMESPACE
      - $NAME
```

### Example 3: Container Vulnerability Scanning with `trivy`
```yaml
plugins:
  trivy-scan:
    shortCut: Shift-T
    confirm: false
    description: "Trivy Scan"
    scopes:
      - pods
    command: trivy
    background: false
    args:
      - k8s
      - --report
      - summary
      - pod
      - $NAME
      - -n
      - $NAMESPACE
```

---

## 18. Custom Views & Custom JSONPath Columns (`views.yaml`)

Customize table columns and expose custom JSONPath attributes directly in K9s tables.

Configuration file: `~/.config/k9s/views.yaml`

```yaml
k9s:
  views:
    v1/pods:
      columns:
        - AGE
        - NAMESPACE
        - NAME
        - STATUS
        - RESTARTS
        - CPU
        - MEM%
        - IP
        - NODE
        - QOS:
            path: .status.qosClass
        - ZONE:
            path: .metadata.labels['topology.kubernetes.io/zone']
```

---

## 19. Custom Hotkeys (`hotkeys.yaml`) & Aliases (`aliases.yaml`)

### Custom Fast-Navigation Hotkeys
Jump directly to frequently used views with dedicated keys:

Configuration file: `~/.config/k9s/hotkeys.yaml`
```yaml
hotKeys:
  Shift-1:
    shortCut: Shift-1
    description: "Prod Deployments"
    command: deploy production
  Shift-2:
    shortCut: Shift-2
    description: "Staging Pods"
    command: pod staging
  Shift-3:
    shortCut: Shift-3
    description: "Cluster Nodes"
    command: node
```

### Custom Command Aliases
Define fast aliases in `~/.config/k9s/aliases.yaml`:
```yaml
aliases:
  pp: v1/pods
  dp: apps/v1/deployments
  cert: cert-manager.io/v1/certificates
  vs: networking.istio.io/v1alpha3/virtualservices
```

---

## 20. Terminal Themes & Skins (`skins/`)

Customize the entire color palette (Solarized, Dracula, Gruvbox, Nord, Cyberpunk):
1. Place skin YAML files in `~/.config/k9s/skins/`.
2. Reference the skin in `~/.config/k9s/config.yaml`:

```yaml
k9s:
  ui:
    skin: dracula
```

To enable a transparent terminal background, ensure `bgColor: "default"` is set in your skin YAML.

---

## 21. Deep Configuration Reference (`config.yaml`)

Full annotated configuration schema for `~/.config/k9s/config.yaml`:

```yaml
k9s:
  refreshRate: 2              # Cluster polling rate in seconds
  maxConnRetry: 5             # Reconnection retries on API loss
  readOnly: false             # Global read-only safety toggle

  ui:
    enableMouse: false        # Enable terminal mouse click selection
    headless: false           # Run without visual TUI headers
    logoless: false           # Hide the ASCII art K9s logo
    crumbsLess: false         # Hide breadcrumbs for compact screens
    reactive: false           # High refresh UI reactivity
    noIcons: false            # Set to true if terminal fonts lack glyphs/icons
    skin: default             # Active skin theme

  logger:
    tail: 500                 # Initial lines fetched on log view (default: 100)
    buffer: 5000              # Maximum memory buffer lines for logs
    sinceSeconds: -1          # -1 = all available logs, or seconds (e.g. 3600)
    textWrap: false           # Wrap log lines automatically
    showTime: true            # Prefix logs with ISO timestamps

  shellPod:
    image: nicolaka/netshoot  # Image used for node shells ('s' on node) & debug
    namespace: default        # Namespace to launch root debug shells
    limits:
      cpu: "100m"
      memory: "100Mi"
    tolerations:              # Required to schedule shells onto master or tainted nodes
      - operator: Exists

  thresholds:
    cpu:
      critical: 90            # Red color threshold for CPU usage %
      warn: 70                # Yellow color threshold for CPU usage %
    memory:
      critical: 90            # Red color threshold for Memory usage %
      warn: 70                # Yellow color threshold for Memory usage %

  clusters:
    # Context-specific overrides
    production-cluster:
      readOnly: true          # Permanently lock production into read-only
      namespace:
        active: production
        favorites:
          - production
          - monitoring
          - kube-system

    dev-cluster:
      readOnly: false         # Allow full edits on dev
      namespace:
        active: default
        favorites:
          - default
          - staging
```

---

## 22. Troubleshooting & Environment Variables

### Common Issues & Fixes

1. **Icons show up as broken squares (`□`)**:
   * *Cause*: Your terminal font is missing Nerd Font glyphs.
   * *Fix*: Set `ui.noIcons: true` in `config.yaml` or install a Nerd Font (JetBrainsMono Nerd Font, FiraCode).

2. **CPU and Memory Gauges show empty or `n/a`**:
   * *Cause*: Kubernetes `metrics-server` is either not deployed or unhealthy in your cluster.
   * *Fix*: Ensure metrics-server pods are running in `kube-system`.

3. **Locating K9s Files & Logs (`k9s info`)**:
   * Run `k9s info` in your shell to print exact paths for configuration files, active cluster logs, and screen dumps.

### Environment Variable Overrides

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Override configuration directory
export K9S_CONFIG_DIR="$HOME/.config/k9s"

# Override log directory
export K9S_LOGS_DIR="/tmp/k9s-logs"

# Specify default editor for 'e' (edit)
export EDITOR="vim"
# or for VS Code
export KUBE_EDITOR="code --wait"
```

---

## 23. Expert-Level Hidden Mechanics & Edge Cases

### 1. Per-Cluster Context Read-Only Lock
Instead of manually typing `k9s --readonly`, you can lock production contexts to read-only in `config.yaml` (`clusters.<context>.readOnly: true`). K9s will dynamically switch safety modes when you hop between staging and production via `:ctx`.

### 2. Dedicated Cluster & Namespace Event Stream (`:events` / `:ev`)
The fastest way to troubleshoot sudden outages:
* Type **`:events`** or **`:ev`**.
* Streams all cluster events in real time (OOMKills, FailedScheduling, Evictions, Probe Timeouts).
* Filter directly by reason: `/FailedScheduling` or `/Unhealthy`.

### 3. Direct CRD Group-Version-Resource (GVR) Navigation
Skip the `:crd` browser and navigate straight to any custom operator resource by full GVR path:
```text
:certificates.v1.cert-manager.io
:virtualservices.v1alpha3.networking.istio.io
:prometheuses.v1.monitoring.coreos.com
```

### 4. Scheduling Node Shells on Tainted / Master Nodes
By adding `tolerations: [{ operator: Exists }]` under `shellPod` in `config.yaml`, pressing `s` on master/control-plane nodes or specialized GPU nodes with taints will successfully schedule the root diagnostic shell.

### 5. Multi-Kubeconfig Concatenation
Manage multi-cloud infrastructure by combining kubeconfigs without merging files:
```bash
KUBECONFIG=~/.kube/eks-prod.yaml:~/.kube/gke-stage.yaml:~/.kube/homelab.yaml k9s
```
Switch between AWS, GCP, and local clusters seamlessly using **`:ctx`**.

### 6. Zero-Port Auto-Allocation
Leaving the local port blank or entering `0` when setting up a port-forward (`Shift-F`) instructs K9s to bind an ephemeral free port automatically, preventing port conflicts when forwarding multiple instances of the same service.

---

## 24. Master Quick-Reference Cheat Sheet

| Category | Shortcut | Description |
| :--- | :--- | :--- |
| **Navigation** | `:pod` / `:po` | Pods |
| | `:deploy` / `:dp` | Deployments |
| | `:svc` / `:ing` | Services / Ingresses |
| | `:node` / `:no` | Cluster Nodes |
| | `:ns` | Switch active namespace |
| | `:ctx` | Switch Kubernetes cluster contexts |
| | `:events` / `:ev` | Real-time cluster event stream |
| | `:helm` | Helm Releases |
| | `:crd` | Custom Resource Definitions |
| | `:popeye` | Run Popeye cluster audit |
| | `:pulses` | Real-time cluster health summary |
| | `:pf` | Manage active Port-Forwards |
| **Pod Actions** | `l` | View container logs |
| | `s` | Exec interactive container shell |
| | `Shift-F` | Establish local port forward |
| | `Ctrl-D` | Delete pod |
| | `d` | Describe pod |
| | `y` / `e` | View YAML / Edit YAML |
| **Node Actions** | `s` | **Root Host Shell** on the node |
| | `c` / `u` | Cordon / Uncordon node |
| | `d` | Safely drain node |
| **Workload Actions** | `s` | Scale replicas |
| | `r` | Rollout restart |
| **Log Tools** | `p` | View previous / crashed container logs |
| | `a` | Toggle auto-scroll |
| | `t` | Toggle timestamps |
| | `w` | Toggle word wrap |
| | `0`..`9` | Switch container |
| | `s` | Save logs to disk |
| **Search & Sort** | `/` | Regex search / label filter (`/-l key=val`) |
| | `/!<term>` | Inverse filter (exclude matches) |
| | `0` | View across all namespaces |
| | `Shift-C` / `Shift-M` | Sort by CPU / Memory |
| | `Shift-A` / `Shift-S` | Sort by Age / Status |
| **Batch & Advanced** | `Ctrl-Space` | Mark row for batch delete/logs |
| | `Shift-B` | Run HTTP benchmark on port-forwarded target |
| | `Ctrl-E` | Export current screen/table snapshot to disk |
| | `x` (in Secrets) | Toggle base64 decode |
| | `?` | Contextual hotkey help menu |
| | `:q` / `Ctrl-C` | Exit K9s |
