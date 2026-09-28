# Auto-Restart & Reboot Configuration Guide

This document summarizes how auto-restart on machine reboot is configured across all services managed by this Ansible project (`jenkins-cac`).

---

## 1. Overview & Architecture

When a VM reboots, all services are configured to automatically boot back up without manual intervention. The infrastructure uses two complementary strategies depending on how each service is deployed:

1. **Docker-Native Engine Restart Policies (`restart: unless-stopped`)**: Docker Engine automatically starts containers on boot when `docker.service` starts.
2. **Systemd Unit Files (`enabled: true`)**: Linux systemd manages native binaries and systemd wrappers around Docker Compose stacks.

---

## 2. Service Inventory & Auto-Restart Matrix

### Server 1: `gcp-vm-1`

| Service | Environment | Auto-Restart Method | Configuration Location |
| :--- | :--- | :--- | :--- |
| **Jenkins** | Native Linux | Systemd (`jenkins.service`) | `/lib/systemd/system/jenkins.service` |
| **SonarQube** | Native Java | Systemd (`sonarqube.service`) | `/etc/systemd/system/sonarqube.service` |
| **Trivy Server** | Native Binary | Systemd (`trivy-server.service`) | `/etc/systemd/system/trivy-server.service` |

---

### Server 2: `gcp-vm-2`

| Service | Environment | Auto-Restart Method | Configuration Location |
| :--- | :--- | :--- | :--- |
| **DefectDojo** | Docker Compose | Docker Engine (`unless-stopped`) | `/opt/defectdojo/docker-compose.override.yml` |
| **Harbor** | Docker Compose | Systemd Wrapper (`harbor.service`) | `/etc/systemd/system/harbor.service` |
| **Nexus** | Docker Container | Docker Engine (`unless-stopped`) | Ansible `community.docker.docker_container` |
| **Vault** | Native Binary | Systemd (`vault.service`) | `/etc/systemd/system/vault.service` |

---

## 3. Detailed Service Configurations

### 1. DefectDojo (Docker Compose Override)
DefectDojo uses a `docker-compose.override.yml` file deployed into `/opt/defectdojo/` via Ansible:

```yaml
services:
  uwsgi:
    restart: unless-stopped
  postgres:
    restart: unless-stopped
  redis:
    restart: unless-stopped
  celeryworker:
    restart: unless-stopped
  celerybeat:
    restart: unless-stopped
  nginx:
    restart: unless-stopped
  initializer:
    restart: "no"
```
* **Ansible Template Location**: [`roles/defectdojo/templates/docker-compose.override.yml.j2`](roles/defectdojo/templates/docker-compose.override.yml.j2)

---

### 2. Harbor (Systemd Wrapper)
Harbor wraps its Docker Compose stack inside a systemd service unit at `/etc/systemd/system/harbor.service`:

```ini
[Unit]
Description=Harbor container registry (docker compose stack)
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/harbor
ExecStart=/usr/bin/docker compose -f /opt/harbor/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f /opt/harbor/docker-compose.yml down

[Install]
WantedBy=multi-user.target
```
* **Ansible Template Location**: [`roles/harbor/templates/harbor.service.j2`](roles/harbor/templates/harbor.service.j2)

---

### 3. Nexus (Docker Container Restart Policy)
Nexus is configured in Ansible via the `docker_container` task module with `restart_policy: unless-stopped`:

```yaml
- name: Run Nexus Repository Manager container
  community.docker.docker_container:
    name: nexus
    image: "sonatype/nexus3:latest"
    restart_policy: unless-stopped
```
* **Ansible Task Location**: [`roles/nexus/tasks/main.yml`](roles/nexus/tasks/main.yml)

---

### 4. Native Systemd Services (Jenkins, SonarQube, Trivy, Vault)
Native Linux services are registered with systemd and enabled via Ansible tasks:

```yaml
- name: Ensure service is enabled and started on boot
  ansible.builtin.systemd:
    name: "{{ service_name }}"
    enabled: true
    state: started
```

---

## 4. Useful Management Commands

### Check Status & Container Health
```bash
# Check all running Docker containers
sudo docker ps -a

# Check systemd service status (e.g. Harbor, Jenkins, SonarQube, Vault)
sudo systemctl status harbor
sudo systemctl status jenkins
sudo systemctl status sonarqube
sudo systemctl status vault
```

### Manual Restart Commands
```bash
# Restart DefectDojo
cd /opt/defectdojo && sudo docker compose restart

# Restart Harbor
sudo systemctl restart harbor

# Restart Nexus
sudo docker restart nexus
```

---

## 5. Troubleshooting 502 Bad Gateway

If Nginx returns a **502 Bad Gateway** after a reboot:
1. Verify if Docker daemon is active: `sudo systemctl status docker`
2. Check if the backend containers are running: `sudo docker ps -a`
3. View Nginx proxy logs: `sudo tail -n 50 /var/log/nginx/error.log`
4. Re-run Ansible playbook to apply auto-restart configurations:
   ```bash
   ansible-playbook -i inventories/dev/hosts.ini playbooks/site.yml
   ```
