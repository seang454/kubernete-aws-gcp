# ---------------------------------------------------------------------------
# AWS VM Module for Jenkins & CI/CD Service Platform
# ---------------------------------------------------------------------------

# 1. VPC & Subnet resolution
data "aws_vpc" "default" {
  count   = var.enabled && var.instance_count > 0 && (var.vpc_id == null || var.vpc_id == "") ? 1 : 0
  default = true
}

locals {
  resolved_vpc_id = var.vpc_id != null && var.vpc_id != "" ? var.vpc_id : try(data.aws_vpc.default[0].id, "")
  ssh_public_key  = trimspace(var.ssh_public_key) != "" ? trimspace(var.ssh_public_key) : trimspace(file(pathexpand(var.ssh_public_key_path)))
}

data "aws_subnets" "available" {
  count = var.enabled && var.instance_count > 0 && length(var.subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.resolved_vpc_id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(var.enabled && var.instance_count > 0 ? (length(var.subnet_ids) > 0 ? var.subnet_ids : try(data.aws_subnets.available[0].ids, [])) : [])
  id       = each.value
}

# 2. Dynamic AZ Discovery
data "aws_availability_zones" "available" {
  count = var.enabled && var.instance_count > 0 && var.auto_discover_up_zones ? 1 : 0
  state = "available"
}

locals {
  configured_zones = length(var.zones) > 0 ? var.zones : []

  discovered_up_zones = var.enabled && var.instance_count > 0 && var.auto_discover_up_zones ? try(data.aws_availability_zones.available[0].names, []) : local.configured_zones

  # Priority 1: User preferred zones (var.zones) in order, confirmed available and not blocked.
  preferred_up_zones = var.auto_discover_up_zones ? [
    for z in local.configured_zones : z
    if contains(local.discovered_up_zones, z)
    && !contains(var.blocked_zones, z)
  ] : [
    for z in local.configured_zones : z
    if !contains(var.blocked_zones, z)
  ]

  # Priority 2: User fallback zones (var.fallback_zones) in order, confirmed available and not blocked.
  fallback_up_zones = var.auto_discover_up_zones ? [
    for z in var.fallback_zones : z
    if contains(local.discovered_up_zones, z)
    && !contains(local.preferred_up_zones, z)
    && !contains(var.blocked_zones, z)
  ] : []

  # Priority 3: Dynamic remaining UP availability zones in the region discovered via AWS API.
  dynamic_remaining_up_zones = var.auto_discover_up_zones ? [
    for z in local.discovered_up_zones : z
    if !contains(local.preferred_up_zones, z)
    && !contains(local.fallback_up_zones, z)
    && !contains(var.blocked_zones, z)
  ] : []

  candidate_zones = concat(
    local.preferred_up_zones,
    local.fallback_up_zones,
    local.dynamic_remaining_up_zones
  )

  usable_zones = local.candidate_zones

  az_to_subnets = {
    for s in data.aws_subnet.selected : s.availability_zone => s.id...
  }

  zones_with_subnets = [
    for z in local.usable_zones : z
    if contains(keys(local.az_to_subnets), z)
  ]

  effective_zones = length(local.zones_with_subnets) > 0 ? local.zones_with_subnets : (
    length(local.usable_zones) > 0 ? local.usable_zones : ["ap-southeast-1a"]
  )

  # Machine Type Fallback Handling (Priority 1, 2, 3)
  fallback_machine_candidates = distinct(compact(concat(
    var.fallback_machine_types,
    contains(var.random_resource_type, "Standard") ? ["t4g.small", "t3.medium", "t3a.medium", "t2.medium"] : [],
    contains(var.random_resource_type, "High CPU") ? ["c6g.large", "c5.large", "c6i.large"] : [],
    contains(var.random_resource_type, "High Memory") ? ["r6g.large", "r5.large"] : []
  )))

  usable_fallback_machines = [
    for m in local.fallback_machine_candidates : m
    if !contains(var.blocked_machine_types, m)
  ]

  default_fallback_machine = length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[0] : "t4g.small"
}

# 3. Dynamic AMI Resolution (Ubuntu 24.04 LTS Noble)
data "aws_ami" "ubuntu_amd64" {
  count       = var.enabled && var.instance_count > 0 && (var.ami_id == null || var.ami_id == "") ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "ubuntu_arm64" {
  count       = var.enabled && var.instance_count > 0 && (var.ami_id == null || var.ami_id == "") ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  is_arm_machine = anytrue([
    for m in var.machine_types :
    can(regex("^(t4g|m6g|c6g|r6g|c7g|m7g|r7g|a1|im4gn|is4gen)\\.", m))
  ])

  resolved_ami_id = var.ami_id != null && var.ami_id != "" ? var.ami_id : (
    local.is_arm_machine ? try(data.aws_ami.ubuntu_arm64[0].id, "") : try(data.aws_ami.ubuntu_amd64[0].id, "")
  )
}

# 4. SSH Key Pair
resource "aws_key_pair" "this" {
  count           = var.enabled && var.instance_count > 0 && local.ssh_public_key != "" ? 1 : 0
  key_name_prefix = "${var.name}-key-"
  public_key      = local.ssh_public_key

  tags = merge(var.tags, {
    Name = "${var.name}-key"
  })
}

# 5. Security Group
resource "aws_security_group" "this" {
  count       = var.enabled && var.instance_count > 0 ? 1 : 0
  name_prefix = "${var.name}-sg-"
  description = "Security group for ${var.name} service VMs"
  vpc_id      = local.resolved_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSH rule
resource "aws_security_group_rule" "ssh" {
  count             = var.enabled && var.instance_count > 0 && length(var.ssh_source_ranges) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_source_ranges
  security_group_id = aws_security_group.this[0].id
  description       = "SSH access"
}

# Public web service rules (80, 443)
resource "aws_security_group_rule" "public_services" {
  for_each = toset(var.enabled && var.instance_count > 0 ? [for p in var.public_service_ports : tostring(p)] : [])

  type              = "ingress"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  cidr_blocks       = var.public_service_source_ranges
  security_group_id = aws_security_group.this[0].id
  description       = "Public web traffic port ${each.value}"
}

# Additional backend service rules (8000, 8080, etc.)
resource "aws_security_group_rule" "additional_services" {
  for_each = toset(var.enabled && var.instance_count > 0 ? [for p in var.additional_service_ports : tostring(p)] : [])

  type              = "ingress"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  cidr_blocks       = var.additional_service_source_ranges
  security_group_id = aws_security_group.this[0].id
  description       = "Service backend port ${each.value}"
}

# Outbound egress (all)
resource "aws_security_group_rule" "egress_all" {
  count             = var.enabled && var.instance_count > 0 ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this[0].id
  description       = "Allow all outbound traffic"
}

# 6. EC2 Machine Plan
locals {
  machines = [
    for index in range(var.instance_count) : {
      index        = index
      global_index = index + 1 + var.index_offset
      name         = format("%s-%d", var.name, index + 1 + var.index_offset)
      zone         = length(local.effective_zones) > 0 ? local.effective_zones[index % length(local.effective_zones)] : ""
      subnet_id    = length(local.effective_zones) > 0 && contains(keys(local.az_to_subnets), local.effective_zones[index % length(local.effective_zones)]) ? local.az_to_subnets[local.effective_zones[index % length(local.effective_zones)]][0] : ""
      machine_type = contains(var.blocked_machine_types, var.machine_types[min(index, length(var.machine_types) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[index % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.machine_types[min(index, length(var.machine_types) - 1)]
    }
  ]
}

# 7. EC2 Instances
resource "aws_instance" "this" {
  count = var.enabled ? var.instance_count : 0

  ami                         = local.resolved_ami_id
  instance_type               = local.machines[count.index].machine_type
  subnet_id                   = local.machines[count.index].subnet_id != "" ? local.machines[count.index].subnet_id : null
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.this[0].id]
  key_name               = length(aws_key_pair.this) > 0 ? aws_key_pair.this[0].key_name : null

  root_block_device {
    volume_size           = var.boot_disk_size_gb
    volume_type           = var.boot_disk_type
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${local.machines[count.index].name}-root"
    })
  }

  tags = merge(var.tags, {
    Name = local.machines[count.index].name
    Role = "service-node"
  })


}

# 8. Elastic IPs (Static Public IPs)
resource "aws_eip" "this" {
  count = var.enabled && var.allocate_elastic_ips ? var.instance_count : 0

  domain   = "vpc"
  instance = aws_instance.this[count.index].id

  tags = merge(var.tags, {
    Name = "${local.machines[count.index].name}-eip"
  })

  depends_on = [aws_instance.this]
}
