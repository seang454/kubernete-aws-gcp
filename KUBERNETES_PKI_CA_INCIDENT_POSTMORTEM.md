# Kubernetes PKI CA Split-Brain Incident & Resolution Postmortem

## Date
September 14, 2026

---

## 1. What was the problem? (Incident Summary & Root Cause)

When `master01` and `master02` (Google Cloud Platform) were replaced earlier, they were fresh virtual machines with clean disks.

### 1.1 Certificate Authority (CA) Split-Brain
* When Kubespray (`cluster.yml`) was executed, Kubespray inspected the first node listed in the control plane inventory (`[kube_control_plane]`), which is **`master01`**.
* Because `master01` was fresh and lacked the `/etc/kubernetes/ssl` directory, Kubespray assumed it was setting up a brand-new cluster.
* Kubespray executed `kubeadm init` on `master01`, which generated a **brand-new Certificate Authority (`ca.crt` / `ca.key`)** and **Service Account signing key (`sa.key` / `sa.pub`)**. It then propagated these new certificates to `master02`.
* However, **`master03`** (AWS), all 4 worker nodes (`worker01..worker04`), and the existing etcd database were still running on the **original cluster CA and keys** created on September 11.

#### Verification of the Split-Brain:
```text
# md5sum /etc/kubernetes/ssl/ca.crt
master03: ef499be2c5700858e7944b8ea472ab5a  (Original Cluster CA)
worker01: ef499be2c5700858e7944b8ea472ab5a  (Original Cluster CA)
worker02: ef499be2c5700858e7944b8ea472ab5a  (Original Cluster CA)
worker03: ef499be2c5700858e7944b8ea472ab5a  (Original Cluster CA)
worker04: ef499be2c5700858e7944b8ea472ab5a  (Original Cluster CA)
------------------------------------------------------------------
master01: 830fcc16d55942528d10f04ad901e1a1  [Mismatched New CA]
master02: 830fcc16d55942528d10f04ad901e1a1  [Mismatched New CA]
```

### 1.2 The Resulting Failures
1. **`401 Unauthorized` in Kubelet**:
   Kubelet on `master01` and `master02` attempted to connect to the cluster API server, but its client certificates were signed by the newly generated CA. The API server rejected them with `401 Unauthorized`.
2. **Nodes Marked `NotReady`**:
   Because Kubelet could not authenticate, it failed to renew its lease in the `kube-node-lease` namespace. Kubernetes marked both `master01` and `master02` as `NotReady`:
   `NodeStatusUnknown: Kubelet stopped posting node status`.
3. **Calico CNI & Pod Creation Broken**:
   Calico CNI on `master01` and `master02` failed to authenticate against the API server (`connection is unauthorized: Unauthorized`), causing new container sandboxes to fail creation.
4. **Why Kubespray Took So Long / Stalled**:
   Kubespray playbooks retry up to 60 times with 10–30s delays when checking node readiness, etcd health, or cert-manager admission. Because the nodes were unauthorized, every readiness check waited for its maximum timeout (15–30+ minutes per stalled step).

---

## 2. What was fixed? (Surgical Resolution)

Instead of re-running the entire 45-minute Kubespray playbook, the issue was fixed surgically in minutes:

### Step 1: Extracted Authentic Cluster CA & SA Keys
Exported the genuine cluster Certificate Authority and Service Account keys directly from the surviving master `master03` (AWS):
* `/etc/kubernetes/ssl/ca.crt` & `ca.key`
* `/etc/kubernetes/ssl/front-proxy-ca.crt` & `front-proxy-ca.key`
* `/etc/kubernetes/ssl/sa.key` & `sa.pub`

### Step 2: Synchronized Keys to `master01` and `master02`
* Backed up previous configurations (`/etc/kubernetes/ssl.bak` and `/etc/kubernetes/conf.bak`).
* Overwrote `/etc/kubernetes/ssl/` on `master01` and `master02` with the authentic cluster authority files.

### Step 3: Re-issued Node Certificates & Kubeconfigs
* Re-generated server and client certificates using `kubeadm init phase certs`:
  * `apiserver.crt` / `apiserver.key`
  * `apiserver-kubelet-client.crt` / `apiserver-kubelet-client.key`
  * `front-proxy-client.crt` / `front-proxy-client.key`
* Re-generated all cluster kubeconfig files with `kubeadm init phase kubeconfig all`:
  * `admin.conf`
  * `kubelet.conf`
  * `controller-manager.conf`
  * `scheduler.conf`
* Updated user and root configurations (`~/.kube/config` and `/root/.kube/config`).

### Step 4: Reloaded Services & Calico CNI
* Stopped previous static pod containers (`kube-apiserver`, `kube-controller-manager`, `kube-scheduler`) and restarted `kubelet` on `master01` and `master02`.
* Restarted the `calico-node` DaemonSet pods so that Calico re-issued its local CNI credentials using the correct cluster CA.

---

## 3. Final Cluster Verification

### 3.1 Node Status (`kubectl get nodes -o wide`)
All 7 hybrid multi-cloud nodes are in **`Ready`** status:

```text
NAME       STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
master01   Ready    control-plane   2d11h   v1.34.3   10.0.0.1      <none>        Ubuntu 24.04.4 LTS   7.0.0-1011-gcp   containerd://2.2.1
master02   Ready    control-plane   2d11h   v1.34.3   10.0.0.2      <none>        Ubuntu 24.04.4 LTS   7.0.0-1011-gcp   containerd://2.2.1
master03   Ready    control-plane   2d11h   v1.34.3   10.0.0.3      <none>        Ubuntu 24.04.4 LTS   7.0.0-1012-aws   containerd://2.2.1
worker01   Ready    worker          2d11h   v1.34.3   10.0.0.4      <none>        Ubuntu 24.04.4 LTS   7.0.0-1012-aws   containerd://2.2.1
worker02   Ready    worker          2d11h   v1.34.3   10.0.0.5      <none>        Ubuntu 24.04.4 LTS   7.0.0-1012-aws   containerd://2.2.1
worker03   Ready    worker          2d11h   v1.34.3   10.0.0.6      <none>        Ubuntu 24.04.4 LTS   7.0.0-1012-aws   containerd://2.2.1
worker04   Ready    worker          2d11h   v1.34.3   10.0.0.7      <none>        Ubuntu 24.04.4 LTS   7.0.0-1012-aws   containerd://2.2.1
```

### 3.2 etcd Quorum Health
All 3 control plane nodes report healthy quorum:
* `https://10.0.0.1:2379 is healthy: took = 172ms`
* `https://10.0.0.2:2379 is healthy: took = 171ms`
* `https://10.0.0.3:2379 is healthy: took = 446ms`

### 3.3 Workload & System Pods
All pods across all namespaces (`kube-system`, `ingress-nginx`, `longhorn-system`, `cert-manager`) are in `Running` or `Completed` status with zero failing pods.
