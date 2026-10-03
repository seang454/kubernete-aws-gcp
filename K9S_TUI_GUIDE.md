# K9s Terminal UI (TUI) - Complete User Guide & Reference

K9s is a terminal-based UI to interact with and manage Kubernetes clusters. It speeds up everyday operations by providing real-time resource observation, fast log streaming, pod exec/shelling, YAML editing, scaling, port forwarding, and cluster diagnostics without having to memorize or repeatedly type long `kubectl` commands.

---

## Table of Contents

1. [Launching K9s & CLI Flags](#1-launching-k9s--cli-flags)
2. [Interface Anatomy & Core Mental Model](#2-interface-anatomy--core-mental-model)
3. [Navigation: The Colon (`:`) Commands](#3-navigation-the-colon--commands)
4. [Managing Pods: Logs, Shells, and Debugging](#4-managing-pods-logs-shells-and-debugging)
5. [Managing Workloads: Deployments, DaemonSets, StatefulSets](#5-managing-workloads-deployments-daemonsets-statefulsets)
6. [Managing Nodes: Cordon, Uncordon, and Drain](#6-managing-nodes-cordon-uncordon-and-drain)
7. [Secrets, ConfigMaps, and Storage](#7-secrets-configmaps-and-storage)
8. [Filtering, Sorting, and Namespaces](#8-filtering-sorting-and-namespaces)
9. [Advanced Visualizations: Pulses & X-Ray](#9-advanced-visualizations-pulses--x-ray)
10. [Safety & Customization (Read-Only, Plugins, Aliases)](#10-safety--customization-read-only-plugins-aliases)
11. [Quick Reference Cheat Sheet](#11-quick-reference-cheat-sheet)

---

## 1. Launching K9s & CLI Flags

Start K9s from your terminal with various runtime options:

```bash
# Launch with current kubeconfig context & default namespace
k9s

# Launch directly into a specific namespace
k9s -n production

# Launch viewing all namespaces
k9s -A
# or
k9s --all-namespaces

# Launch targeted to a specific cluster context
k9s --context gke_my-project_us-central1_prod

# Production safety mode: Read-Only (disables delete, edit, shell, scale)
k9s --readonly

# Set refresh rate (default is 2 seconds)
k9s --refresh 1

# Launch directly into a specific resource view
k9s -c pod
k9s -c deploy
```

---

## 2. Interface Anatomy & Core Mental Model

K9s follows Vim-style navigation principles:

* **Top Header**: Displays cluster info, CPU/Memory resource consumption, active context, namespace, and current view version.
* **Main Area**: Interactive table listing the current resources.
* **Menu Bar**: Shows dynamically available hotkeys based on what resource is currently highlighted.
* **Command Bar**: Appears at the bottom when you trigger `:` (commands) or `/` (filters).

### Core Global Hotkeys

| Key | Function |
| :--- | :--- |
| **`?`** | Open contextual Help Modal (shows all hotkeys for the current view) |
| **`:`** | Enter **Command Mode** (switch views, e.g. `:pod`, `:deploy`) |
| **`/`** | Enter **Filter Mode** (filter rows using regex) |
| **`Esc`** | Exit modal, clear filter, or go back to previous view |
| **`j` / `k`** or **`↓` / `↑`** | Navigate down / up |
| **`Enter`** | Drill down into selected item (e.g. into Pod containers, deployment pods) |
| **`Ctrl-C`** or `:q` | Quit K9s |

---

## 3. Navigation: The Colon (`:`) Commands

To switch views, press `:` followed by the resource alias and hit `Enter`:

| Command | Resource / Purpose |
| :--- | :--- |
| `:pod` or `:po` | Pods |
| `:deploy` or `:dp` | Deployments |
| `:svc` | Services |
| `:ing` | Ingresses |
| `:cm` | ConfigMaps |
| `:sec` | Secrets |
| `:ns` | Namespaces (switch active namespace) |
| `:node` or `:no` | Cluster Nodes |
| `:pvc` / `:pv` | Persistent Volume Claims / Persistent Volumes |
| `:sts` | StatefulSets |
| `:ds` | DaemonSets |
| `:cj` / `:job` | CronJobs / Jobs |
| `:ctx` | Context switcher (switch between Kubernetes clusters) |
| `:crds` | Custom Resource Definitions |
| `:pf` | Active Port-Forwards manager |
| `:pulses` | High-level cluster health metrics overview |
| `:xray <resource>` | Tree graph view (e.g., `:xray deploy`, `:xray pod`) |

---

## 4. Managing Pods: Logs, Shells, and Debugging

### Universal Actions on Highlighted Pods

| Key | Action | Description |
| :--- | :--- | :--- |
| **`l`** | **Logs** | Stream live container logs |
| **`s`** | **Shell** | Exec into the container via interactive shell (`bash`/`sh`) |
| **`d`** | **Describe** | Formatted output equivalent to `kubectl describe pod` |
| **`y`** | **YAML** | View raw YAML definition |
| **`e`** | **Edit** | Open pod specification in `$EDITOR` |
| **`Shift-F`** | **Port-Forward** | Set up local port forwarding |
| **`Ctrl-D`** | **Delete** | Delete selected pod (with confirmation) |

### Inside Log View (`l`)

* **`0` - `9`**: Switch between containers inside multi-container pods.
* **`a`**: Toggle auto-scroll / live tailing.
* **`t`**: Toggle log timestamps on/off.
* **`p`**: Toggle **previous logs** (indispensable for debugging `CrashLoopBackOff` pods).
* **`w`**: Toggle word-wrap.
* **`/`**: Search / filter through the log lines.
* **`s`**: Save stream to a local text file.
* **`Esc`**: Exit log viewer.

### Port-Forwarding (`Shift-F`)

1. Highlight the Pod or Service and press **`Shift-F`**.
2. A modal will prompt you for:
   * Container Port
   * Local Port (defaults to match or open free port)
   * Local Host Address (default `localhost`)
3. Hit `OK`.
4. Type **`:pf`** to open the Port-Forward view, check traffic status, or terminate forwards with **`Ctrl-D`**.

---

## 5. Managing Workloads: Deployments, DaemonSets, StatefulSets

When viewing Deployments (`:deploy`), DaemonSets (`:ds`), or StatefulSets (`:sts`):

* **`s` (Scale)**: Prompt to change the replica count.
* **`r` (Restart)**: Triggers a zero-downtime rolling restart (`kubectl rollout restart`).
* **`Enter`**: View the child Pods belonging specifically to this workload.
* **`d`**: Describe workload events, conditions, and replica status.
* **`y`**: View YAML.
* **`e`**: Edit deployment YAML directly; changes take effect immediately upon save.

---

## 6. Managing Nodes: Cordon, Uncordon, and Drain

When in the Node view (`:node`):

* **`c` (Cordon)**: Mark node as unschedulable (no new pods will be scheduled).
* **`u` (Uncordon)**: Mark node as schedulable again.
* **`d` (Drain)**: Evict existing workloads safely according to PodDisruptionBudgets.
* **`y`**: Inspect Node YAML, capacity, and allocatable resources.
* **`Shift-C`**: Sort nodes by CPU allocation/usage.
* **`Shift-M`**: Sort nodes by Memory allocation/usage.

---

## 7. Secrets, ConfigMaps, and Storage

### Secrets (`:sec`)
* Highlight a Secret and press **`Enter`** to inspect keys and values.
* Press **`x`**: Toggles decoding of base64 values directly on screen.

### ConfigMaps (`:cm`)
* Press **`Enter`** to view key-value configurations and file templates.

### Persistent Volumes & Claims (`:pv` / `:pvc`)
* Inspect mount points, access modes (`RWO`, `RWX`), capacity, and binding status (`Bound`, `Pending`).

---

## 8. Filtering, Sorting, and Namespaces

### Switching Namespaces
* **`0`**: View all namespaces simultaneously (`--all-namespaces`).
* **`:ns`**: Open namespace selector table; highlight one and press `Enter`.
* **`1` - `9`**: Jump directly to assigned quick-switch namespaces.

### Search and Regex Filtering
* Press **`/`** to open the filter prompt at the bottom:
  * `/backend`: Matches any resource containing "backend".
  * `/!canary`: **Inverse filter** — hides any resource containing "canary".
  * `Esc`: Clears filter.

### Sorting Rows
* **`Shift-A`**: Sort by Age.
* **`Shift-C`**: Sort by CPU usage.
* **`Shift-M`**: Sort by Memory usage.
* **`Shift-S`**: Sort by Status (`Running`, `Pending`, `Failed`, etc.).
* **`Shift-N`**: Sort by Name.

---

## 9. Advanced Visualizations: Pulses & X-Ray

### Pulses (`:pulses`)
Displays a cluster health cockpit showing high-level status of:
* Pods (Healthy, Pending, Error, Crash)
* Deployments & ReplicaSets
* Nodes and Cluster Allocations

### X-Ray (`:xray <resource>`)
Displays an interactive tree graph showing hierarchical relationships between Kubernetes objects:

```text
:xray deploy
:xray pod
:xray svc
```

*Example hierarchy*: Service $\rightarrow$ Deployment $\rightarrow$ ReplicaSet $\rightarrow$ Pods $\rightarrow$ ConfigMaps & PVCs.

---

## 10. Safety & Customization

### Production Safety
To eliminate accidental deletion or editing in production:
```bash
k9s --readonly
```
This disables `Ctrl-D` (delete), `e` (edit), `s` (shell / scale), and `r` (restart).

### Custom Aliases (`~/.config/k9s/aliases.yaml`)
Create custom shortcuts:
```yaml
aliases:
  pp: v1/pods
  dp: apps/v1/deployments
  cert: cert-manager.io/v1/certificates
```

### Custom Plugins (`~/.config/k9s/plugins.yaml`)
Add custom commands to K9s views. For example, viewing neat YAML using `kubectl-neat`:
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

---

## 11. Quick Reference Cheat Sheet

| Category | Shortcut | Description |
| :--- | :--- | :--- |
| **Navigation** | `:pod` / `:po` | Go to Pods |
| | `:deploy` / `:dp` | Go to Deployments |
| | `:svc` | Go to Services |
| | `:ns` | Switch namespace |
| | `:ctx` | Switch Kubernetes cluster context |
| | `:node` | Go to Nodes |
| | `:pf` | View active Port-Forwards |
| | `:pulses` | Cluster health dashboard |
| **Pod Actions** | `l` | View container logs |
| | `s` | Shell into container |
| | `Shift-F` | Start Port-Forwarding |
| | `Ctrl-D` | Delete pod |
| | `d` | Describe resource |
| | `y` | View YAML |
| | `e` | Edit YAML |
| **Deployment Actions** | `s` | Scale replica count |
| | `r` | Rollout restart |
| **Logs View** | `p` | View previous/crashed container logs |
| | `a` | Toggle auto-scroll |
| | `t` | Toggle timestamps |
| | `0`..`9` | Select container |
| | `s` | Save logs to file |
| **Filtering & Sorting**| `/` | Regex search filter |
| | `/!<term>` | Inverse filter (exclude matches) |
| | `0` | Show all namespaces |
| | `Shift-C` / `Shift-M` | Sort by CPU / Memory |
| | `Shift-A` / `Shift-S` | Sort by Age / Status |
| **Global** | `?` | Contextual Help modal |
| | `Esc` | Clear filter / Back |
| | `:q` / `Ctrl-C` | Exit K9s |
