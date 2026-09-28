locals {
  # Generic domain variables for future roles. If a new role reads service_domain,
  # adding a Cloudflare A/AAAA record can create both its inventory group and this
  # group_vars file without adding another hard-coded Terraform mapping.
  ansible_generic_domain_group_vars = {
    for key, record in var.cloudflare_dns_records :
    (try(trimspace(record.ansible_group), "") != "" ? trimspace(record.ansible_group) : key) => {
      service_domain   = record.hostname
      service_hostname = record.hostname
    }
    if var.enable_cloudflare_dns &&
    try(record.enabled, true) &&
    try(record.create_ansible_group, true) &&
    contains(["A", "AAAA"], upper(record.type)) &&
    try(record.vm_index, null) != null &&
    record.vm_index > 0
  }

  # Existing roles already use role-specific variable names, so keep these
  # compatibility variables. Put secrets and manual overrides in
  # group_vars/<service>.yml or another non-generated Ansible vars file.
  ansible_known_domain_group_vars = {
    defectdojo = {
      defectdojo_domain = try(var.cloudflare_dns_records.defectdojo.hostname, "")
    }

    harbor = {
      harbor_domain = try(var.cloudflare_dns_records.harbor.hostname, "")
    }

    jenkins = {
      jenkins_domain = try(var.cloudflare_dns_records.jenkins.hostname, "")
    }

    nexus = {
      nexus_domain             = try(var.cloudflare_dns_records.nexus.hostname, "")
      nexus_docker_repo_domain = try(var.cloudflare_dns_records.nexus_docker.hostname, "")
    }

    sonarqube = {
      sonarqube_domain = try(var.cloudflare_dns_records.sonarqube.hostname, "")
    }

    trivy = {
      trivy_server_domain = try(var.cloudflare_dns_records.trivy.hostname, "")
    }

    vault = {
      vault_domain = try(var.cloudflare_dns_records.vault.hostname, "")
    }
  }

  ansible_domain_group_vars = {
    for group in setunion(keys(local.ansible_generic_domain_group_vars), keys(local.ansible_known_domain_group_vars)) :
    group => merge(
      lookup(local.ansible_generic_domain_group_vars, group, {}),
      lookup(local.ansible_known_domain_group_vars, group, {})
    )
  }

  ansible_domain_group_vars_files = {
    for group, vars in local.ansible_domain_group_vars : group => vars
    if var.enable_cloudflare_dns && var.enable_ansible_group_vars_domains && (
      contains(keys(local.ansible_effective_service_targets), group) || (
        length(local.ansible_effective_service_targets) == 0 && !local.ansible_has_explicit_service_config
      )
      ) && alltrue([
        for _, value in vars : trimspace(value) != ""
    ])
  }
}

resource "local_file" "ansible_group_vars_domains" {
  for_each = local.ansible_domain_group_vars_files

  # local_file creates the file when it does not exist and rewrites it when
  # Terraform sees the domain value has changed.
  filename = abspath("${path.module}/${var.ansible_group_vars_path}/${each.key}/terraform_domains.yml")

  content = templatefile("${path.module}/templates/ansible_group_vars_domains.tftpl", {
    domain_vars = each.value
  })

  depends_on = [module.cloudflare_dns]
}
