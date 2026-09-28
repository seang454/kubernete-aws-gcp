# Group Vars Override Checklist

Use role defaults for safe fallback values, and use `group_vars` for real environment values.

```text
roles/<role>/defaults/main.yml
  -> safe defaults that explain what the role can use

group_vars/<role>/terraform_domains.yml
  -> Terraform-generated domain values

group_vars/<role>.yml or Ansible Vault
  -> real manual values: email, passwords, secrets, toggles
```

Do not put secrets in `terraform_domains.yml`. Terraform owns that file and rewrites it during `terraform apply`.

Real `group_vars/<role>.yml` files are loaded by Ansible. The `*.yml.example` files are only reference templates.

## Common Values

Set this once in `group_vars/all.yml` if all services use the same email:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
certbot_staging: true
```

Terraform provides domain variables in files like:

```text
group_vars/sonarqube/terraform_domains.yml
group_vars/jenkins/terraform_domains.yml
group_vars/nexus/terraform_domains.yml
```

If you are not using Terraform DNS generation, then you must set the service domain manually in `group_vars/<role>.yml`.

## DefectDojo

Required real values:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
defectdojo_db_password: "REPLACE_WITH_STRONG_PASSWORD"
defectdojo_secret_key: "REPLACE_WITH_RANDOM_50_PLUS_CHARACTER_SECRET"
defectdojo_admin_password: "REPLACE_WITH_STRONG_ADMIN_PASSWORD"
defectdojo_admin_email: "pengseangsim@210.gmail.com"
```

Rules enforced by the role:

```text
defectdojo_db_password must be at least 12 characters
defectdojo_secret_key must be at least 50 characters
defectdojo_admin_password must be at least 12 characters
defectdojo_domain must not be defectdojo.example.com when HTTPS is enabled
certbot_email must not be admin@example.com when HTTPS is enabled
```

Usually keep defaults:

```yaml
defectdojo_version: "2.37.0"
defectdojo_install_dir: /opt/defectdojo
defectdojo_db_host: localhost
defectdojo_db_port: 5432
redis_host: localhost
redis_port: 6379
```

## Jenkins

Required when HTTPS is enabled:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
jenkins_enable_https: true
```

Rules enforced by the role:

```text
jenkins_domain must not be jenkins.example.com when HTTPS is enabled
certbot_email must not be admin@example.com when HTTPS is enabled
```

Usually keep defaults:

```yaml
jenkins_image_version: "lts-jdk21"
jenkins_http_port: 8080
jenkins_agent_port: 50000
jenkins_dind_port: 2376
```

## Nexus

Required when HTTPS is enabled:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
nexus_enable_https: true
```

After the first run and after changing the admin password in the UI, set:

```yaml
nexus_admin_password: "YOUR_CHANGED_NEXUS_ADMIN_PASSWORD"
```

Rules enforced by the role:

```text
nexus_domain must not be nexus.example.com when HTTPS is enabled
nexus_docker_repo_domain must not be docker.example.com when HTTPS is enabled
certbot_email must not be admin@example.com when HTTPS is enabled
nexus_admin_password is needed after the initial password file is no longer usable
```

Usually keep defaults:

```yaml
nexus_image: sonatype/nexus3:latest
nexus_port: 8081
nexus_docker_port: 8082
nexus_docker_repo_name: docker-hosted
nexus_helm_repo_name: helm-hosted
```

## SonarQube

Required real values:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
sonarqube_database_password: "REPLACE_WITH_STRONG_PASSWORD"
sonarqube_enable_https: true
```

Rules enforced by the role:

```text
sonarqube_database_password must be at least 12 characters
sonarqube_domain must not be sonarqube.example.com when HTTPS is enabled
certbot_email must not be admin@example.com when HTTPS is enabled
```

Usually keep defaults:

```yaml
sonarqube_version: "25.12.0.117093"
sonarqube_install_dir: /opt/sonarqube
sonarqube_web_port: 9000
sonarqube_database_host: localhost
sonarqube_database_port: 5432
```

## Trivy

Required when the Trivy server and HTTPS are enabled:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
trivy_server_enable: true
trivy_enable_https: true
```

Rules enforced by the role:

```text
trivy_server_domain must not be trivy.example.com when server HTTPS is enabled
certbot_email must not be admin@example.com when server HTTPS is enabled
```

Usually keep defaults:

```yaml
trivy_install_method: apt
trivy_version: ""
trivy_server_port: 4954
trivy_enable_db_update_cron: false
```

If you want CLI-only Trivy on a host, set:

```yaml
trivy_server_enable: false
```

## Vault

Required real values:

```yaml
certbot_email: "pengseangsim@210.gmail.com"
```

Rules enforced by the role:

```text
vault_domain must not be vault.example.com
certbot_email must not be admin@example.com
```

Usually keep defaults:

```yaml
vault_ui_enabled: true
vault_listener_address: "127.0.0.1:8200"
vault_api_addr: "https://{{ vault_domain }}"
vault_data_dir: "/opt/vault/data"
configure_ufw: false
```

Vault does not use a default admin password. After installation, initialize and unseal Vault manually:

```bash
vault operator init
vault operator unseal
```

## venv_bootstrap

Usually no manual values are required.

Keep shared packages and tools here. Service roles can pass extra packages into:

```yaml
service_config_extra_system_packages: []
service_config_extra_python_packages: []
```

Only override these when you intentionally want a different shared environment:

```yaml
service_config_venv: /opt/service-config-venv
service_config_start_docker: true
service_config_install_glab: true
```
