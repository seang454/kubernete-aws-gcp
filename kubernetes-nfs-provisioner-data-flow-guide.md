# 🎯 Complete Combined Summary: `/data` Folder & Kubernetes Storage

### 1. 📜 What your `kubectl get pv` output means
When `kubectl get pv` returned:
```text
Server IP: nfs-server.internal | Export Path: /data/keycloak-oauth2-keycloak-oauth2-postgres-pvc-b1e978fa-85e2-44b6-b427-353e749321d0
```

This is the **Network Address Pointer** stored in Kubernetes (`etcd`). It tells your worker nodes:
> *"When a Pod needs storage, connect over the network to **`nfs-server.internal`** (`haproxy-1` / `10.146.0.11`) and mount the remote export path **`/data/keycloak-oauth2-keycloak-oauth2-postgres-pvc-b1e978fa...`**."*

---

### 2. ❓ Why don't you see `/data` on your NFS server host OS (`haproxy-1`)?
* **`/data` is NOT a regular Linux folder** on the `/dev/root` filesystem of `haproxy-1`.
* It is a **Virtual Network Export** created in memory by the Ceph MDS container (`7f3f731e2ba9`).

---

### 3. 💽 Where does `/data` physically stay?
* **Physical Hardware:** Storage Disk **`/dev/sdb` (25GB drive)** on `haproxy-1` (replicated across storage nodes).
* **How it is saved:** Files inside `/data` are saved as **raw binary blocks** on `/dev/sdb` by Ceph's BlueStore engine (container `ceph-osd-0`).

---

### 4. 🛠️ How to view your `/data` folder on `haproxy-1` right now:
Run these 3 commands on `haproxy-1`:
```bash
# 1. Create a local temporary mount folder
sudo mkdir -p /mnt/ceph-test

# 2. Mount the local Ceph NFS export
sudo mount -t nfs4 127.0.0.1:/ /mnt/ceph-test

# 3. View your PVC subfolder!
ls -la /mnt/ceph-test
```
