# ansible-role-harbor

Installs [Harbor](https://goharbor.io) using the **official `install.sh` installer script**
(not Helm, not a from-scratch compose file), following the current docs:

- https://goharbor.io/docs/2.15.0/install-config/download-installer/
- https://goharbor.io/docs/2.15.0/install-config/configure-yml-file/
- https://goharbor.io/docs/2.15.0/install-config/run-installer-script/

It installs Harbor **over HTTP** with everything else left at Harbor's
defaults (Trivy included). TLS is intentionally left out of `harbor.yml`
because you're terminating HTTPS yourself in front of Harbor (reverse proxy +
systemd + your existing certbot certificates) — this role does not touch that
part at all.

## What it does

1. Installs curl/tar/gnupg prerequisites (apt or dnf).
2. Installs Docker Engine + the `docker compose` plugin via `get.docker.com`
   if Docker isn't already present.
3. Downloads the Harbor **online** installer tarball for the pinned
   `harbor_version` straight from the GitHub releases page and extracts it to
   `/opt/harbor`.
4. Takes the `harbor.yml.tmpl` that ships **inside that exact release**, and
   patches only: `hostname`, `http.port`, `harbor_admin_password`,
   `database.password`, `data_volume`, `log.*`, `jobservice.max_job_workers`,
   `notification.webhook_job_max_retry`, and Trivy's tunables. Everything
   else in harbor.yml stays at the shipped default.
5. Runs `./install.sh --with-trivy` (Trivy is part of the "everything
   default" install), bringing the full Harbor stack up via docker compose.
6. Drops a `harbor.service` systemd unit wrapping
   `docker compose up -d` / `down` / `restart`, and enables it, so you manage
   Harbor with `systemctl start|stop|restart|status harbor` like any other
   service on the box.

## Requirements

- Target host: Ubuntu/Debian or RHEL/Fedora family, systemd, internet access
  (online installer pulls images from Docker Hub).
- Ansible >= 2.14, collection `ansible.builtin` (ships with Ansible itself).
- Root/become privileges on the target.

## Role variables (see `defaults/main.yml` for the full, commented list)

| Variable | Default | Notes |
|---|---|---|
| `harbor_version` | `v2.15.2` | Must exist as a tag on goharbor/harbor releases |
| `harbor_installer_type` | `online` | or `offline` if the host has no internet |
| `harbor_hostname` | `reg.yourdomain.com` | **Change this** — FQDN clients/docker will use |
| `harbor_http_port` | `80` | Harbor listens plain HTTP; your reverse proxy handles TLS |
| `harbor_admin_password` | `Harbor12345` | Only applied on first boot |
| `harbor_database_password` | `root123` | Local Postgres root password |
| `harbor_data_volume` | `/data` | Where Harbor stores registry data |
| `harbor_with_trivy` | `true` | Full default install includes the scanner |
| `harbor_manage_docker` | `true` | Set `false` if Docker is already managed elsewhere |
| `harbor_docker_users` | `[]` | Users to add to the `docker` group |
| `harbor_manage_systemd` | `true` | Installs the `harbor.service` unit |
| `harbor_force_reinstall` | `false` | Re-runs `install.sh` even if already installed |

## Example playbook

```yaml
- hosts: harbor_servers
  become: true
  roles:
    - role: harbor
      vars:
        harbor_hostname: registry.mycompany.com
        harbor_admin_password: "{{ vault_harbor_admin_password }}"
        harbor_database_password: "{{ vault_harbor_db_password }}"
        harbor_docker_users:
          - deploy
```

Run it:

```sh
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass
```

## After the role runs

- Portal: `http://<harbor_hostname>:<harbor_http_port>` (login `admin` /
  `harbor_admin_password`).
- Manage the stack: `systemctl status|restart harbor`.
- Point your own reverse proxy (nginx/Traefik/whatever you run under
  systemd, fronted by certbot-issued certs) at
  `http://<harbor_host_internal_ip>:{{ harbor_http_port }}` and forward
  `X-Forwarded-Proto: https` — Harbor works fine behind a TLS-terminating
  proxy in `http` mode, you don't need to fill in `harbor.yml`'s own
  `https:` block for that.
- To change settings later, edit `/opt/harbor/harbor.yml` and re-run:
  `cd /opt/harbor && ./install.sh --with-trivy` (or set
  `harbor_force_reinstall: true` and re-run the role).

## Idempotency notes

- Docker install, download/extract, and `install.sh` are all skipped on
  reruns once Harbor is already present (detected via `docker-compose.yml`
  in the install dir), unless `harbor_force_reinstall: true`.
- `harbor.yml` is seeded from `harbor.yml.tmpl` only once (`force: false`),
  so any manual edits you make afterwards are never overwritten by reruns.
