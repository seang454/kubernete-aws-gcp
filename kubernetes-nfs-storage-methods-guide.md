# 📚 Complete Guide: Kubernetes NFS Storage Methods Comparison

This guide explains and compares the **3 different ways** to connect and use NFS storage in Kubernetes, ranging from manual host-level mounts to automated dynamic provisioning with `StorageClass`.

---

## 🔍 Summary Comparison Matrix

| Feature | Method 1: Manual `sudo mount` (`hostPath`) | Method 2: Direct Inline `volumes.nfs` | Method 3: Dynamic `StorageClass` (`nfs-client`) |
| :--- | :--- | :--- | :--- |
| **How it's configured** | SSH into node OS, run `sudo mount` manually, use `hostPath` | Hardcode NFS IP & Export Path directly in Pod YAML | Request storage via a `PersistentVolumeClaim` (PVC) |
| **Who manages it?** | System Administrator / DevOps | Application Developer in YAML | Kubernetes (`nfs-client-provisioner`) |
| **Automatic Node Mount?** | ❌ **No** (Fails if Pod moves to another node) | ✅ **Yes** (Kubernetes handles OS mount automatically) | ✅ **Yes** (Kubernetes handles OS mount automatically) |
| **Directory Isolation** | ❌ **None** (All pods share 1 single folder) | ❌ **None** (All pods share 1 single folder) | ✅ **Yes** (Each PVC gets its own private subfolder) |
| **Hardcoded IPs in Pods?** | N/A (`hostPath`) | ❌ **Yes** (Must put `10.148.0.12` in every Pod manifest) | ✅ **No** (Developers never need to know the NFS IP) |
| **Lifecycle Cleanup** | ❌ Manual file deletion | ❌ Manual file deletion | ✅ Automated (Clean up or archive on PVC deletion) |
| **Best Used For** | Quick manual host testing / OS debugging | Legacy apps or simple fixed static shares | **Production Kubernetes Workloads** |

---

## 🛠️ Detailed Breakdown of the 3 Methods

### 1️⃣ Method 1: Manual SSH + `sudo mount` (Host-Level `hostPath`)

In this approach, you manually SSH into the Kubernetes worker node OS and mount the NFS share onto the node file system.

#### Execution Steps:
1. SSH into **Worker Node 1**:
   ```bash
   sudo mkdir -p /opt/nfs/data
   sudo mount 10.148.0.12:/opt/nfs/data /opt/nfs/data
   ```
2. Create a test file:
   ```bash
   echo "hello from host" > /opt/nfs/data/test.txt
   ```
3. Reference the local directory in Pod YAML using `hostPath`:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: manual-mount-pod
   spec:
     containers:
       - name: app
         image: nginx
         volumeMounts:
           - name: host-vol
             mountPath: /usr/share/nginx/html
     volumes:
       - name: host-vol
         hostPath:
           path: /opt/nfs/data
   ```

#### ❌ Why this is BAD for Kubernetes:
* **No Mobility**: If Kubernetes reschedules your Pod to **Worker Node 2** where you forgot to run `sudo mount`, the container will fail to start or point to an empty local folder.
* **High Maintenance**: You must SSH into every node in the cluster to set up mounts manually.
* **No Safety/Isolation**: All containers mounted to `/opt/nfs/data` read/write to the exact same folder.

---

### 2️⃣ Method 2: Direct Inline NFS (`volumes.nfs`)

Kubernetes has a built-in NFS volume driver. Instead of mounting NFS on the host OS manually, you specify the NFS server IP and export path directly inside the Pod YAML manifest.

#### Pod YAML Example:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: direct-nfs-pod
spec:
  containers:
    - name: web-app
      image: nginx
      volumeMounts:
        - name: register-vol
          mountPath: /app/data
  volumes:
    - name: register-vol
      nfs:
        server: 10.148.0.12     # Hardcoded NFS Server IP
        path: /opt/nfs/data      # Hardcoded NFS Export Path
```

#### How it works:
When Kubernetes schedules this Pod onto any worker node, the node's `kubelet` uses the host's **`nfs-common`** driver to automatically mount `10.148.0.12:/opt/nfs/data` directly for the Pod. You **do not** need to run `sudo mount` via SSH.

#### ✅ Pros & ❌ Cons:
* ✅ **Pros**: Fully automated host mounting by Kubernetes. Pods can move to any worker node seamlessly.
* ❌ **Cons**: 
  1. **Hardcoded Configuration**: If your NFS IP changes from `10.148.0.12` to `10.148.0.20`, you must update dozens of application YAML files.
  2. **Shared Overwrite Hazard**: Every Pod mounting `/opt/nfs/data` shares the exact same root directory. If App A writes `data.log`, it can overwrite App B's `data.log`.

---

### 3️⃣ Method 3: Dynamic Provisioning with `StorageClass` (`nfs-client`) ⭐ *(Recommended Best Practice)*

This is the cloud-native, production standard. You decouple storage infrastructure from application code using a **StorageClass** and **PersistentVolumeClaim (PVC)**.

#### How it works:
1. The Cluster Administrator installs the `nfs-client-provisioner` pod once.
2. Application developers request storage by creating a `PersistentVolumeClaim` (PVC).
3. The provisioner automatically creates a dedicated, isolated subfolder on the NFS server (e.g. `/opt/nfs/data/default-register-pvc-pvc-8f92a1/`).
4. Kubernetes binds the PV to the PVC and mounts it to the Pod.

#### Step-by-Step Manifests:

##### Step 1: Create a PVC (`pvc.yaml`)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: register-pvc
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods can read/write simultaneously
  storageClassName: nfs-client  # Uses your nfs-client provisioner
  resources:
    requests:
      storage: 5Gi
```

##### Step 2: Reference PVC in your Pod (`pod.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: register-app-pod
spec:
  containers:
    - name: register-app
      image: nginx
      volumeMounts:
        - name: register-vol
          mountPath: /app/data
  volumes:
    - name: register-vol
      persistentVolumeClaim:
        claimName: register-pvc  # References the PVC name above
```

#### ✅ Why Method 3 is the Best Practice:
1. **100% Automated Subdirectories**: App A and App B get completely isolated subfolders automatically. They will never overwrite each other's data.
2. **No Hardcoded IPs**: Developers don't need to know `10.148.0.12` or `/opt/nfs/data`. If the storage infrastructure IP changes, admins only update the `StorageClass` / Provisioner deployment **once**.
3. **Automated Lifecycle**: When a PVC is deleted, the `StorageClass` can automatically clean up or archive the deleted storage folder according to its `reclaimPolicy`.

---

## 🏗️ Architecture Visualization

```text
==================================================================================================
METHOD 1: Manual hostPath (Fragile & Manual)
==================================================================================================
[ Admin SSH ] ──> `sudo mount` ──> [ Host OS: /opt/nfs/data ] <── [ Pod hostPath ] (Node Specific!)

==================================================================================================
METHOD 2: Direct Inline NFS (Automated Mount, Hardcoded IPs)
==================================================================================================
[ Pod Manifest (server: 10.148.0.12) ] ──> Kubelet + nfs-common ──> [ NFS Export: /opt/nfs/data ]

==================================================================================================
METHOD 3: Dynamic Provisioner + StorageClass (Production Standard)
==================================================================================================
[ App PVC Manifest ] ──> [ StorageClass: nfs-client ]
                               │
                               ▼ (Auto-creates subfolder)
                 [ nfs-client-provisioner Pod ]
                               │
                               ▼
        [ NFS Export: /opt/nfs/data/default-register-pvc-pvc-12345/ ]
```

---

## 🌐 Component Location Matrix: Client vs. Server vs. Network Bridge

To clearly understand where each component lives and operates:

### 1. 💻 CLIENT SIDE ONLY (Kubernetes Worker Nodes & Workload Pods)
These components run **only** on the Kubernetes client nodes:
* **`nfs-common` package**: Linux kernel drivers (`mount.nfs4`, `rpcbind`) installed on worker node OS.
* **Workload Container Mounts**: Mount paths inside application containers (e.g., `/usr/share/nginx/html`, `/app/data`).
* **Local Node Mount Directory**: Local folder on node OS if mounted manually (e.g., `/mnt/nfs` or `/opt/nfs/data`).
* **`nfs-client-provisioner` Pod**: Controller pod running in K8s (namespace `kube-system`).

---

### 2. 🖥️ SERVER SIDE ONLY (Storage Nodes & Gateways)
These components run **only** on your Storage Cluster nodes (`haproxy-1`, `haproxy-2`, `haproxy-3`):
* **`nfs-ganesha` Daemon**: The NFS server process running in user-space listening for incoming NFS connections.
* **`nfs-ganesha-ceph` Plugin**: Translates NFS file requests directly into CephFS API calls.
* **Ceph Storage Cluster**: Daemons (`ceph-mon`, `ceph-mgr`, `ceph-osd`, `ceph-mds`) managing raw disks (`/dev/sdb`).
* **High Availability Stack**: `pacemaker`, `corosync`, and `pcsd` managing the cluster state and failovers.
* **Physical Disks & Files**: The physical storage media where your actual files are written and preserved.

---

### 3. 🤝 NETWORK BRIDGE (Interacts Between Client & Server)
These parameters bridge the communication between Client and Server:
* **Virtual IP (VIP)**: E.g., `10.146.0.11` (or `10.148.0.12`). Managed by Pacemaker on the server, targeted by Kubelet/NFS drivers on the client.
* **NFS Protocol & Port**: NFSv4 protocol communicating over **TCP Port 2049**.
* **NFS Pseudo Export Path**: The shared top-level export folder defined on the server (e.g., `/data` or `/opt/nfs/data`) and mounted by clients.

---

## 🔄 End-to-End Step-by-Step Execution Sequence (From User Request to Disk Write)

Below is the exact step-by-step lifecycle showing **who triggers the command**, **which tool executes it**, and **where it is processed**:

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: Cluster Setup & Groundwork (DevOps Admin)                                                                │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 [1. Admin runs Ansible/Terraform] ──> Installs Ceph + NFS-Ganesha on Servers & nfs-common on K8s Worker Nodes
                                   ──> Deploys StorageClass (nfs-client) & Provisioner Pod into K8s

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: Application Developer Requests Storage                                                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 [2. Developer] ──> Runs: `kubectl apply -f pvc.yaml` (Requests 5GB storage via storageClassName: nfs-client)

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: Dynamic Provisioning (Kubernetes Controller)                                                             │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 [3. K8s API] ──> Notifies `nfs-client-provisioner` Pod
 [4. Provisioner Pod] ──> Connects to NFS Server VIP (10.146.0.11) over TCP 2049
                      ──> Creates folder: `/data/default-my-pvc-pvc-12345/`
                      ──> Registers PV object in K8s and binds it to PVC

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: Application Pod Mount & Scheduling (Kubelet & OS)                                                       │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 [5. Developer] ──> Runs: `kubectl apply -f pod.yaml` (References PVC)
 [6. K8s Scheduler] ──> Assigns Pod to `Worker-Node-2`
 [7. Kubelet on Worker-Node-2] ──> Calls Linux Kernel via `nfs-common` (`mount.nfs4`)
                                ──> Mounts `10.146.0.11:/data/default-my-pvc-pvc-12345` onto node file system
                                ──> Passes mount into container at `/app/data`

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 5: Application File Write (Client -> Network)                                                               │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 [8. App Container] ──> Executes write: `echo "hello" > /app/data/file.txt`
 [9. Host Linux Kernel] ──> `nfs-common` driver converts file write into NFSv4 RPC packets
                        ──> Transmits TCP packets over port 2049 to VIP `10.146.0.11`

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PHASE 6: Server Persistence (NFS Gateway -> CephFS -> Disk)                                                       │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 [10. Pacemaker VIP] ──> Forwards TCP 2049 packets to Active Gateway (`haproxy-1`)
 [11. nfs-ganesha] ──> Receives NFSv4 write request
 [12. nfs-ganesha-ceph] ──> Translates NFS write call to CephFS C-library (`libcephfs.so`)
 [13. Ceph MDS] ──> Updates directory metadata for `/default-my-pvc-pvc-12345/file.txt`
 [14. Ceph OSD Daemons] ──> Writes 3x replicated BlueStore data blocks directly to `/dev/sdb` physical disks!
```

### 📋 Phase-by-Phase Details Table

| Phase | Who / What triggers it? | Which Tool / Software executes it? | Where does it execute? | Action Output |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: Setup** | DevOps Admin | Ansible / `cephadm` / `apt install` | Storage Nodes & K8s Master | NFS-Ganesha & Ceph cluster ready; `nfs-common` installed |
| **Phase 2: PVC Request** | Developer | `kubectl apply -f pvc.yaml` | K8s Control Plane API | Unbound PVC created in K8s API |
| **Phase 3: Provisioning** | K8s API | `nfs-client-provisioner` Pod | `kube-system` namespace | Subfolder created on NFS export; PV created & bound |
| **Phase 4: Node Mounting** | K8s Kubelet | Linux `nfs-common` (`mount.nfs4`) | K8s Worker Node OS | Remote NFS folder attached to local node file system |
| **Phase 5: Client Write** | Application Code | Linux Kernel Network Stack | Container -> Worker Node | NFSv4 TCP RPC packets sent over network to `10.146.0.11:2049` |
| **Phase 6: Disk Persistence**| Pacemaker VIP | `nfs-ganesha` -> `nfs-ganesha-ceph` -> Ceph OSD | Storage Gateway Tier (`haproxy-1`) | Data written across 3x replicated BlueStore `/dev/sdb` disks |

---

## 🔬 Deep-Dive: What Happens on the Node File System (Phase 4 Detailed)

When Kubernetes mounts an NFS share onto a worker node, it performs a 3-step filesystem mechanism on the node OS:

### 1. The Exact Path on the Worker Node OS
Kubernetes (`kubelet`) creates a specific, isolated directory on the worker node's root file system using this path structure:

```text
/var/lib/kubelet/pods/<POD-UUID>/volumes/kubernetes.io~nfs/<VOLUME-NAME>
```

**Real Example**:
```text
/var/lib/kubelet/pods/b5ac88e8-7b0e-4b08-8f41-287762296903/volumes/kubernetes.io~nfs/pvc-efc064c3-9659-4775-a094-0dbbe460aadb
```

---

### 2. How `kubelet` Executes the OS Mount
The `kubelet` daemon running on the host OS invokes the Linux kernel mount command using **`nfs-common`** drivers:

```bash
# Executed by kubelet under the hood on the Worker Node OS:
sudo mount -t nfs4 -o soft,timeo=300 \
  10.146.0.11:/data/default-my-pvc-pvc-12345 \
  /var/lib/kubelet/pods/a3b819e2-4f11-419b-8e2a-71829abc1234/volumes/kubernetes.io~nfs/register-vol
```

If you SSH into the worker node OS while the Pod is running and inspect `/var/lib/kubelet/pods/a3b819e2.../volumes/kubernetes.io~nfs/register-vol`, you will see the exact contents of the NFS share!

---

### 3. How the Host Directory Is Connected to the Container (Linux Bind Mount)
Once the NFS share is mounted on the host OS at `/var/lib/kubelet/pods/...`, the container runtime (`containerd` / `docker`) connects it to the container using **Linux Mount Namespaces & Bind Mounts**:

```text
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ WORKER NODE HOST OS FILE SYSTEM                                                             │
│                                                                                             │
│  Path: /var/lib/kubelet/pods/a3b8.../volumes/kubernetes.io~nfs/register-vol               │
│        (Mounted to NFS Server 10.146.0.11:/data/default-my-pvc-pvc-12345)                   │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               │ (Linux Kernel `--bind` Mount Namespace)
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ CONTAINER INSIDE THE POD                                                                    │
│                                                                                             │
│  Path: /app/data                                                                            │
│        (Sees files locally, but writes pass directly through host mount to NFS!)            │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

#### Summary of the Flow:
1. `kubelet` mounts NFS to `/var/lib/kubelet/pods/<pod-id>/volumes/kubernetes.io~nfs/<vol-name>`.
2. Container runtime bind-mounts that directory into `/app/data` inside the container.
3. The application writes to `/app/data` -> passes through `/var/lib/kubelet/...` -> travels over network TCP 2049 -> saved on NFS Server disks!

---

## ⚡ PV Creation Timeline: Dynamic vs. Static Provisioning

### 1. Dynamic Provisioning (Your `nfs-client` Setup) ⭐
**YES! The PV is created AUTOMATICALLY after you create the PVC.**

```text
[ Developer creates PVC ] ──> [ StorageClass calls Provisioner ] ──> [ PV created & bound AUTOMATICALLY ]
      (Step 1)                            (Step 2)                                (Step 3)
```

* You **only** apply `pvc.yaml`.
* The `nfs-client-provisioner` pod sees the PVC, creates the NFS subfolder, and **automatically generates the `PersistentVolume` (PV) object in Kubernetes for you**.
* You never need to write or apply a `pv.yaml` manifest.

---

### 2. Static Provisioning (Old / Manual Method)
In static provisioning (without a dynamic provisioner pod), the creation order is reversed:

```text
[ Admin creates PV manually ] ──> [ Developer creates PVC ] ──> [ K8s binds existing PV to PVC ]
         (Step 1)                         (Step 2)                          (Step 3)
```

* An Admin must write and apply `pv.yaml` manually **first**.
* Then a Developer applies `pvc.yaml`.
* Kubernetes matches the PVC to the pre-existing static PV.

---

## 🛠️ Kubernetes Storage Provisioner Tools & Honest Evaluation

### 📊 Storage Provisioner Comparison Matrix

| Provisioner Tool | Storage Type | Best Used For | Complexity |
| :--- | :--- | :--- | :--- |
| **`nfs-subdir-external-provisioner`** *(Your Current Setup)* | File Storage (NFS) | Multi-pod shared folders (`ReadWriteMany`), Nextcloud, web uploads | 🟢 **Very Low** |
| **Rook-Ceph / Ceph CSI** | Block (`RBD`) & File (`CephFS`) | Native high-performance enterprise Ceph cluster integration | 🔴 **High** |
| **Longhorn** | Distributed Block Storage | Cloud-native replicated block storage with built-in GUI | 🟡 **Medium** |
| **OpenEBS** | Local / Container Attached | High-performance container-attached database storage | 🟡 **Medium** |
| **GCP Persistent Disk CSI** (`pd.csi.storage.gke.io`) | Cloud Block Storage | Managed GCP Cloud Disks (SSD / Standard) | 🟢 **Very Low** |
| **AWS EBS CSI** (`ebs.csi.aws.com`) | Cloud Block Storage | Managed AWS Elastic Block Store | 🟢 **Very Low** |

---

### 🏆 Honest Winner Recommendation by Use Case

There is no single "magic bullet" storage tool for every workload. Here is the honest, real-world evaluation:

1. **For Shared Web Files / Uploads / Nextcloud (`ReadWriteMany`)**:
   * ⭐ **Winner**: **`nfs-subdir-external-provisioner`** *(Your Current Setup)*
   * **Why**: It is by far the **lightest, simplest, and most efficient** tool for sharing folders across multiple pods simultaneously.
   * **Your Architecture Advantage**: Paired with Ceph + NFS-Ganesha + Pacemaker HA underneath ([`HA-NFS-Ceph-Architecture-Guide.md`](file:///home/seang/nfs-cluster/HA-NFS-Ceph-Architecture-Guide.md)), you get simple Kubernetes mounts on the client side with 3x enterprise Ceph disk replication on the server side!

2. **For Production Cloud (GCP / AWS)**:
   * ⭐ **Winner**: **Cloud Provider CSI Drivers (`pd.csi.storage.gke.io` / `ebs.csi.aws.com`)**
   * **Why**: Zero storage server maintenance. Cloud providers handle disk replacements, hardware failures, and backups automatically.

3. **For High-Performance Production Databases (MySQL, PostgreSQL, Redis)**:
   * ⭐ **Winner**: **Rook-Ceph (Ceph RBD)** or **Cloud Block Storage**
   * **Why**: Databases require raw **Block Storage** for minimal I/O latency. NFS introduces network overhead for random database write operations.

4. **For Easiest All-in-One Cloud-Native Storage with GUI**:
   * ⭐ **Winner**: **Longhorn**
   * **Why**: Built by Rancher, includes a built-in web dashboard, 1-click S3 backups, and simple installation.

---

## 💾 Deep-Dive: What is Block Storage & Why Databases Require It

### 1. What is Block Storage (Ceph RBD / GCP PD / AWS EBS)?
**Block Storage** provides a raw, unformatted virtual hard drive directly to the operating system (e.g., `/dev/sdb` or `/dev/vdb`). 

Unlike NFS (File Storage), which presents a pre-formatted network folder with file structures, **Block Storage gives raw empty disk sectors** that the OS or database formats with low-level filesystems (`ext4`, `xfs`).

---

### 2. File Storage (NFS) vs. Block Storage (Ceph RBD / Cloud Disk)

| Characteristic | File Storage (NFS / `nfs-client`) | Block Storage (Ceph RBD / Cloud Disk) |
| :--- | :--- | :--- |
| **How OS sees it** | Network folder share (`/mnt/nfs`) | Raw unformatted virtual disk (`/dev/sdb`) |
| **Access Mode** | `ReadWriteMany` (RWX - Shared by 100+ pods) | `ReadWriteOnce` (RWO - Exclusive to 1 pod) |
| **Random Write Speed** | ⚠️ Slower (Network NFS protocol overhead) | ⚡ **Ultra Fast (Direct block I/O)** |
| **`fsync()` Reliability** | ⚠️ Can lag over network RPC calls | ⚡ Immediate hardware-level write confirmation |
| **Best For** | Web uploads, images, CMS, logs, PDF sharing | **Databases (MySQL, Postgres, MongoDB, Redis)** |

---

### 3. Why Databases (MySQL, PostgreSQL, Redis) MUST Use Block Storage

1. **High IOPS & Low Latency for Random 4KB Writes**:
   Databases write tiny chunks of index data and WAL logs thousands of times per second. NFS introduces network file-locking and RPC overhead for every file write. Block Storage bypasses network file protocols for direct, raw block writes.
   
2. **Strict Transaction Safety (`fsync()` & WAL Logs)**:
   When a database commits a transaction, it executes a system command (`fsync()`) demanding the OS confirm data is physically written to disk. Block Storage guarantees this immediately. Over NFS, network delays can corrupt database indexes during sudden power failures.

3. **Exclusive Single-Owner Protection (`ReadWriteOnce`)**:
   A database engine (like MySQL master) requires exclusive control over its storage. Block Storage locks the volume to 1 Pod at a time (`ReadWriteOnce`), preventing accidental corruption from other pods.

---

### 💡 Simple Analogy to Remember

* **File Storage (NFS)** = Like **Google Drive / Dropbox**. Perfect for multiple users sharing photos, documents, and web assets.
* **Block Storage (Ceph RBD / Cloud Disk)** = Like plugging a **High-Speed External NVMe SSD** directly into your server. Required for heavy database software.

---

## ⚠️ How to Achieve `ReadWriteMany` (RWX) with Block Storage / Ceph

If you attempt to mount a standard Block Device (formatted with `ext4` or `xfs`) on multiple nodes simultaneously, **IT WILL IMMEDIATELY CORRUPT DATA**. Standard filesystems do not have a network locking manager to inform Node B when Node A alters disk blocks.

Here are the 4 proper engineering solutions if you need shared `ReadWriteMany` storage:

### Solution 1: Use CephFS instead of Ceph RBD ⭐ *(Recommended Native Ceph Way)*
* **How it works**: Ceph provides **CephFS**, a distributed POSIX filesystem built on top of Ceph storage pools.
* **Result**: Supports **`ReadWriteMany` (RWX)** natively across hundreds of pods!
* **Your Architecture**: In your setup ([`HA-NFS-Ceph-Architecture-Guide.md`](file:///home/seang/nfs-cluster/HA-NFS-Ceph-Architecture-Guide.md)), NFS-Ganesha exposes CephFS over NFS, giving your Kubernetes pods full `ReadWriteMany` access.

### Solution 2: Use Application-Level Database Clustering (Best for Databases)
* **How it works**: Do NOT try to share 1 single block disk between database pods. Instead, deploy a database cluster (e.g. PostgreSQL Patroni, MySQL Galera, or MongoDB Replica Set).
* **Result**: Each database pod gets its own private Block Disk (`ReadWriteOnce`). The database software handles data synchronization over the network.

### Solution 3: Layer an NFS / Object Gateway on top of Cloud Block Storage
* **How it works**: Attach a Cloud Disk (GCP PD / AWS EBS) to 1 Gateway Node, run an NFS Server or MinIO Object Store container on that node, and export it over the network to other pods.
* **Result**: Other pods mount the gateway share as `ReadWriteMany`.

### Solution 4: Use a Clustered Filesystem (GFS2 / OCFS2) *(Advanced)*
* **How it works**: Format the raw block device with a specialized cluster-aware filesystem like **GFS2** or **OCFS2**.
* **Result**: Allows multi-node simultaneous block writes via a Distributed Lock Manager (DLM).
* **Warning**: Extremely complex to maintain in Kubernetes.

---

## 🔑 Deep-Dive: Kubernetes Access Modes Explained

In Kubernetes, **Access Modes** define **how many worker nodes (or pods) can mount and access a PersistentVolume at the exact same time, and with what permissions**.

### 📊 Summary Access Modes Comparison Matrix

| Access Mode | Abbreviation | Node Limit | Read / Write | Typical Storage Backend | Best Used For |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`ReadWriteOnce`** | `RWO` | **1 Node** | Read + Write | Block Storage (GCP PD, AWS EBS, Ceph RBD) | Single-instance Databases (MySQL, Postgres, Redis) |
| **`ReadWriteMany`** | `RWX` | **Many Nodes** | Read + Write | File Storage (NFS, CephFS, AWS EFS) | Web uploads, Nextcloud, CMS assets, shared logs |
| **`ReadOnlyMany`** | `ROX` | **Many Nodes** | **Read-Only** | File Storage or Shared Block Disks | Static reference data, ML model weights, config datasets |
| **`ReadWriteOncePod`**| `RWOP` | **1 Single Pod** | Read + Write | Block Storage (K8s 1.22+) | Strict single-pod database instances |

---

### 🔍 Detailed Explanation of Each Mode

#### 1. `ReadWriteOnce` (RWO)
* **What it means**: The volume can be mounted as Read-Write by **only 1 Kubernetes worker node** at a time.
* **How it works**: Multiple pods running on the **same single node** can access it, but pods running on **different worker nodes** are blocked from mounting it.
* **Why it's used**: Required for Block Storage (GCP PD / AWS EBS / Ceph RBD) to prevent filesystem corruption.

#### 2. `ReadWriteMany` (RWX) ⭐ *(Your NFS Setup)*
* **What it means**: The volume can be mounted as Read-Write by **many worker nodes** simultaneously.
* **How it works**: Pods distributed across completely different worker nodes across the cluster can read and write to the exact same shared directory at the same time over the network.
* **Why it's used**: Perfect for shared web uploads, Nextcloud data, CMS media assets, or shared logs.

#### 3. `ReadOnlyMany` (ROX)
* **What it means**: The volume can be mounted as **Read-Only** by **many worker nodes** simultaneously.
* **How it works**: Pods across any worker node can open and read files, but any attempt to create, edit, or delete files will throw a `Permission Denied / Read-Only File System` error.
* **Why it's used**: Great for sharing static datasets, AI/ML model weights, or static web assets that should never be altered at runtime.

#### 4. `ReadWriteOncePod` (RWOP)
* **What it means**: The volume can be mounted as Read-Write by **only 1 single Pod** in the entire cluster.
* **How it works**: Stricter than `RWO`. Even if two pods live on the exact same worker node, Kubernetes will refuse to attach the volume to the second pod.
* **Why it's used**: Essential for stateful database pods where you want to guarantee 100% exclusive disk ownership.

---

### ❓ FAQ: Do `WriteOnlyMany`, `WriteOnlyOne`, or `ReadOnlyOne` Exist?

**Short Answer**: **NO. Kubernetes does NOT have `WriteOnlyMany`, `WriteOnlyOne`, or `ReadOnlyOne` access modes.**

If you type `WriteOnlyMany` or `WriteOnlyOne` in a PVC manifest, Kubernetes will reject it with a validation error:
`Unsupported value: "WriteOnlyMany": supported values: "ReadWriteOnce", "ReadOnlyMany", "ReadWriteMany", "ReadWriteOncePod"`.

#### Why Don't "Write-Only" Mount Modes Exist?
1. **Linux POSIX Requirements**: Operating systems cannot mount a filesystem in "Write-Only" mode. To write a file, the Linux kernel must read directory inodes, file metadata, sector allocations, and file handles. 
2. **File Permissions vs. Mount Modes**: Write-only permissions exist at the file level (`chmod 0222` or `O_WRONLY` file descriptors), but **not** at the filesystem volume mount level.

#### How to achieve "ReadOnly on 1 Node/Pod" (`ReadOnlyOne`)?
Kubernetes does not have a separate `ReadOnlyOne` mode name because you can easily achieve this in Pod YAML using the `readOnly: true` setting on a standard `ReadWriteOnce` volume:

```yaml
spec:
  containers:
    - name: my-app
      image: nginx
      volumeMounts:
        - name: my-vol
          mountPath: /app/data
          readOnly: true    # <-- Makes a ReadWriteOnce volume Read-Only for this Pod!
  volumes:
    - name: my-vol
      persistentVolumeClaim:
        claimName: my-rwo-pvc
```

---

## 🧪 Real Live Cluster Empirical Ceph Inspection Trace

Below is the complete step-by-step empirical verification executed on **`haproxy-1`**, showing the exact commands run and the real cluster output produced:

---

### 1️⃣ Check Ceph Cluster Topology & OSD Nodes

#### Command Executed:
```bash
sudo ceph osd tree
```

#### Real Cluster Output:
```text
ID  CLASS  WEIGHT   TYPE NAME           STATUS  REWEIGHT  PRI-AFF
-3         0.02440      host haproxy-1                           
 0    ssd  0.02440          osd.0           up   1.00000  1.00000
-5         0.02440      host haproxy-2                           
 1    ssd  0.02440          osd.1           up   1.00000  1.00000
-7         0.02440      host haproxy-3                           
 2    ssd  0.02440          osd.2           up   1.00000  1.00000
```

#### 🔍 What this means:
* You have **3 physical storage daemons** (`osd.0`, `osd.1`, `osd.2`) running across **3 separate servers** (`haproxy-1`, `haproxy-2`, `haproxy-3`).
* All 3 storage nodes are **`up`** and healthy, managing the SSD disks (`/dev/sdb`).

---

### 2️⃣ List the Raw Ceph Binary Object IDs

#### Command Executed:
```bash
sudo rados -p cephfs_data ls
```

#### Real Cluster Output:
```text
100000001f7.00000000
```

#### 🔍 What this means:
* This is the **actual internal Ceph Object ID** created when Kubernetes wrote your `welcome-test.txt` / folder entries to the `cephfs_data` storage pool!
* In Ceph, files are not saved as `.txt` files—they are stored under this unique 64-bit object identifier.

---

### 3️⃣ Map the Object to Physical Disks & Servers (3x Replication Proof)

#### Command Executed:
```bash
sudo ceph osd map cephfs_data 100000001f7.00000000
```

#### Real Cluster Output:
```text
osdmap e63 pool 'cephfs_data' (1) object '100000001f7.00000000' -> pg 1.43b1c7f6 (1.16) -> up ([0,2,1], p0) acting ([0,2,1], p0)
```

#### 🔍 What this means:
Look at **`acting ([0,2,1])`**:
* **`0`** = The Primary data write was written to **`osd.0` on `haproxy-1`**.
* **`2`** = The First replicated copy was written to **`osd.2` on `haproxy-3`**.
* **`1`** = The Second replicated copy was written to **`osd.1` on `haproxy-2`**.

👉 **This is empirical proof that your file data is automatically 3x replicated across all 3 servers simultaneously!** If `haproxy-1` crashes, `haproxy-2` and `haproxy-3` already have exact copies of your data.

---

### 4️⃣ Inspect Object Metadata & Payload Size

#### Command Executed:
```bash
sudo rados -p cephfs_data stat 100000001f7.00000000
```

#### Real Cluster Output:
```text
cephfs_data/100000001f7.00000000 mtime 2026-08-13T06:47:15.000000+0000, size 192
```

#### 🔍 What this means:
* **`size 192`**: The exact physical binary payload size (**192 bytes**) written to Ceph for that object!
* **`mtime`**: The exact UTC timestamp when the write occurred on your cluster.

---

### 🏆 Summary of Your Architecture Journey

```text
[ 1. Kubernetes Pod ] ──(Writes file)──> [ 2. nfs-client Provisioner ]
                                                  │
                                                  ▼
[ 4. Saved to /dev/sdb Disks ] <── [ 3. Ceph translates to Object 100000001f7.00000000 ]
     ├── osd.0 on haproxy-1 (Primary)
     ├── osd.1 on haproxy-2 (Replica 1)
     └── osd.2 on haproxy-3 (Replica 2)
```

---

## 🌐 Deep-Dive: What is `/data`, Where Does It Stay, and Network Export Paths?

### 1️⃣ What is `/data` and Where Does It Stay?

* **`/data` is a Virtual Network Address (NFS Export Handle)**:
  * Think of `/data` like a **website URL** (e.g., `http://storage-server/data`).
  * It does **NOT** exist as a normal Linux folder on `/dev/root` of `haproxy-1`.
  * Instead, `/data` is a **virtual network alias** managed in memory by the **NFS-Ganesha** daemon.

* **Where does the content of `/data` actually stay?**:
  * The actual content of `/data` lives inside **CephFS**, stored as **3x replicated binary objects** on the physical disks (**`/dev/sdb`**) across `haproxy-1`, `haproxy-2`, and `haproxy-3`.

---

### 2️⃣ What Happens When `nfs-client-provisioner` Creates a Folder?

When this step executes in Kubernetes:

```text
[Provisioner Pod] ──> Connects to NFS Server VIP (10.146.0.11) over TCP 2049
                  ──> Creates folder: `/data/default-my-pvc-pvc-12345/`
```

Here is the exact step-by-step mechanism:

```text
1. PROVISIONER CONTAINER              2. NETWORK LAYER                     3. STORAGE SERVER (haproxy-1)
┌───────────────────────────┐        ┌─────────────────────────┐          ┌───────────────────────────────────┐
│ Runs inside container:    │        │ NFS `CREATE` RPC Packet │          │ NFS-Ganesha receives request      │
│ `mkdir                    │ ─────> │ over TCP Port 2049 to   │ ───────> │ Translates `/data` to CephFS Root │
│ /persistentvolumes/       │        │ `10.146.0.11`           │          │ Calls `libcephfs.so`              │
│ default-my-pvc-pvc-12345` │        └─────────────────────────┘          └─────────────────┬─────────────────┘
└───────────────────────────┘                                                                │
                                                                                             ▼
                                                                          4. CEPH PHYSICAL DISKS (/dev/sdb)
                                                                          ┌───────────────────────────────────┐
                                                                          │ Creates directory inode in        │
                                                                          │ `cephfs_metadata` pool & saves    │
                                                                          │ 3x replicated binary objects!     │
                                                                          └───────────────────────────────────┘
```

#### Step-by-Step Flow:
1. **Provisioner Container**: The provisioner pod mounts `10.146.0.11:/data` internally inside its container at `/persistentvolumes`.
2. **Issues `mkdir`**: It runs `mkdir /persistentvolumes/default-my-pvc-pvc-12345`.
3. **NFS Network Transmission**: The container sends an NFS `CREATE` network request over TCP 2049 to `10.146.0.11`.
4. **NFS-Ganesha Processing**: `nfs-ganesha` on `haproxy-1` receives the request for export `/data` and calls CephFS C-libraries (`libcephfs.so`).
5. **Ceph Metadata Creation**: Ceph creates a new directory entry inside its **`cephfs_metadata`** pool.
6. **Physical Disk Result**: The folder structure is now established inside CephFS and replicated across the **`/dev/sdb`** SSD disks on `haproxy-1`, `haproxy-2`, and `haproxy-3`.

---

### 3️⃣ How You Can View This Created Folder

Depending on where you look, the folder appears as:

| Layer | Path / Location | How to View It |
| :--- | :--- | :--- |
| **Inside Provisioner Container** | `/persistentvolumes/default-my-pvc-pvc-12345/` | `kubectl exec` inside provisioner pod |
| **Network Export Path** | `10.146.0.11:/data/default-my-pvc-pvc-12345/` | Mount via `mount -t nfs4` |
| **On any Node (with `/mnt/nfs`)**| `/mnt/nfs/default-my-pvc-pvc-12345/` | `sudo ls -la /mnt/nfs/` |
| **Ceph Storage Pool** | `cephfs_metadata` directory inode entry | `sudo rados -p cephfs_metadata ls` |

---

### 4️⃣ What is a Network Export Path?

A **Network Export Path** is the **network web-address/URL** exposed by a storage server (like NFS) so that client machines across the network can connect and mount remote storage.

#### 💡 Real-World Analogy:
* **Local File Path**: `C:\Users\Sean\Documents\file.txt`  
  *(Only visible to your local machine. No one else on the network can access it).*
* **Network Export Path**: `10.146.0.11:/data`  
  *(Like a shared Google Drive link or network share URL. Any authorized machine on the network can connect to it).*

#### 🔍 How It Works in Your Project:
In your cluster, **`10.146.0.11:/data`** is your **Network Export Path**:

```text
[ NFS Server IP ]  +  [ Export Name ]  =  [ Network Export Path ]
  10.146.0.11              /data            10.146.0.11:/data
```

1. **`10.146.0.11`**: The IP address of your HA NFS Gateway server (Virtual IP).
2. **`/data`**: The export path/name configured inside NFS-Ganesha ([`ganesha.conf.j2`](file:///home/seang/nfs-cluster/ansible-nfs-cluster-genesha/roles/nfs_ganesha/templates/ganesha.conf.j2#L9)).
3. **Combined (`10.146.0.11:/data`)**: The complete address that Kubernetes nodes and Pods use to mount storage remotely:
   ```bash
   mount -t nfs4 10.146.0.11:/data /mnt/nfs
   ```

#### 📋 Summary Table:

| Term | Example | What it means |
| :--- | :--- | :--- |
| **Local Path** | `/var/lib/kubelet` | A folder sitting directly on one machine's hard drive. |
| **Network Export Path** | `10.146.0.11:/data` | A storage path made available over the network for other machines to connect to. |
| **Mount Point** | `/mnt/nfs` | The local folder where a client attaches a Network Export Path. |

