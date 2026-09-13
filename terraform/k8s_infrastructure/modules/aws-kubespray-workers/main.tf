# ---------------------------------------------------------------------------
# AWS Kubespray Worker Nodes Module
# Implements full architectural parity with GCP module:
#  1. Dynamic AZ Discovery & Health Checking (state = "available")
#  2. Machine Type Stockout & Fallback Handling (blocked_machine_types)
#  3. Preflight Safety Preconditions (terraform_data.preflight)
#  4. Static Elastic IP Reservation (preserved across stop/start)
#  5. Storage Architecture (Boot + Optional Secondary EBS Data Volume)
#  6. Power State Control (RUNNING vs TERMINATED)
#  7. Selective Node Deletion (exclude_nodes)
#  8. Multi-Cloud & Cross-VPC Firewall / Ingress Rules
# ---------------------------------------------------------------------------

# 1. VPC & Subnet resolution
data "aws_vpc" "default" {
  count   = var.enabled && (var.worker_count + var.control_plane_count) > 0 && (var.vpc_id == null || var.vpc_id == "") ? 1 : 0
  default = true
}

locals {
  resolved_vpc_id = var.vpc_id != null && var.vpc_id != "" ? var.vpc_id : try(data.aws_vpc.default[0].id, "")
}

data "aws_subnets" "available" {
  count = var.enabled && (var.worker_count + var.control_plane_count) > 0 && length(var.subnet_ids) == 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.resolved_vpc_id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(var.enabled && (var.worker_count + var.control_plane_count) > 0 ? (length(var.subnet_ids) > 0 ? var.subnet_ids : try(data.aws_subnets.available[0].ids, [])) : [])
  id       = each.value
}

# 2. Dynamic AZ Discovery & Zone Health (Concept 1)
data "aws_availability_zones" "available" {
  count = var.enabled && (var.worker_count + var.control_plane_count) > 0 && var.auto_discover_up_zones ? 1 : 0
  state = "available"
}

locals {
  configured_zones = length(var.zones) > 0 ? var.zones : []

  discovered_up_zones = var.enabled && (var.worker_count + var.control_plane_count) > 0 && var.auto_discover_up_zones ? try(data.aws_availability_zones.available[0].names, []) : local.configured_zones

  # Preferred configured zones that are confirmed available/UP
  preferred_up_zones = length(local.configured_zones) > 0 ? [
    for z in local.configured_zones : z
    if contains(local.discovered_up_zones, z)
  ] : local.discovered_up_zones

  # Fallback zones from available zones not explicitly in preferred
  fallback_up_zones = [
    for z in local.discovered_up_zones : z
    if !contains(local.preferred_up_zones, z)
  ]

  candidate_zones = concat(local.preferred_up_zones, local.fallback_up_zones)

  # Filter out blocked availability zones
  usable_zones = [
    for z in local.candidate_zones : z
    if !contains(var.blocked_zones, z)
  ]

  # Map AZ to available Subnet IDs in this VPC
  az_to_subnets = {
    for s in data.aws_subnet.selected : s.availability_zone => s.id...
  }

  # Usable zones that also have an available subnet in the VPC
  zones_with_subnets = [
    for z in local.usable_zones : z
    if contains(keys(local.az_to_subnets), z)
  ]

  effective_zones = length(local.zones_with_subnets) > 0 ? local.zones_with_subnets : ["no-usable-zone"]
}

# 3. Machine Type Stockout & Fallback Handling (Concept 2)
locals {
  fallback_machine_candidates = distinct(compact(concat(
    var.fallback_machine_types,
    contains(var.random_resource_type, "Standard") ? ["t3.medium", "t3a.medium", "t2.medium", "m5.large"] : [],
    contains(var.random_resource_type, "High CPU") ? ["c5.large", "c6i.large"] : [],
    contains(var.random_resource_type, "High Memory") ? ["r5.large", "r6i.large"] : []
  )))

  usable_fallback_machines = [
    for m in local.fallback_machine_candidates : m
    if !contains(var.blocked_machine_types, m)
  ]

  default_fallback_machine = length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[0] : "t3.medium"
}

# 4. AMI Resolution (Official Canonical Ubuntu 24.04 LTS)
data "aws_ami" "ubuntu" {
  count       = var.enabled && (var.worker_count + var.control_plane_count) > 0 && (var.ami_id == null || var.ami_id == "") ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*",
      "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  resolved_ami_id = var.ami_id != null && var.ami_id != "" ? var.ami_id : try(data.aws_ami.ubuntu[0].id, "")
}

# 5. SSH Key Pair
resource "aws_key_pair" "this" {
  count           = var.enabled && (var.worker_count + var.control_plane_count) > 0 ? 1 : 0
  key_name_prefix = "${var.instance_name_prefix}-key-"
  public_key      = trimspace(var.ssh_public_key)

  tags = merge(var.tags, {
    Name    = "${var.instance_name_prefix}-key"
    cluster = var.cluster_name
  })
}

# 6. Security Group & Firewall Rules (Concept 8)
resource "aws_security_group" "worker" {
  name_prefix = "${var.instance_name_prefix}-worker-sg-"
  description = "Security group for Kubernetes worker nodes managed by Kubespray"
  vpc_id      = local.resolved_vpc_id

  tags = merge(var.tags, {
    Name    = "${var.instance_name_prefix}-worker-sg"
    cluster = var.cluster_name
    role    = "worker"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress SSH (22)
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "SSH access"
}

# Ingress Kubelet API (10250) - user configurable (disabled by default when empty)
resource "aws_security_group_rule" "kubelet" {
  count             = length(var.kubelet_source_ranges) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  cidr_blocks       = var.kubelet_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "Kubelet API access"
}

# Intra-cluster worker communication (self)
resource "aws_security_group_rule" "intra_cluster" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.worker.id
  description       = "Intra-cluster worker communication"
}

# Cross-cloud cluster traffic from GCP control plane
resource "aws_security_group_rule" "cross_cluster" {
  count             = var.enable_cross_cluster_rule ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = var.cluster_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "Cross-cloud cluster traffic from GCP control plane"
}

# Kubernetes NodePort service range (30000-32767)
resource "aws_security_group_rule" "nodeport" {
  count             = length(var.nodeport_source_ranges) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = var.nodeport_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "Kubernetes NodePort service ranges"
}

# Ingress WireGuard VPN (51820/udp)
resource "aws_security_group_rule" "wireguard" {
  count             = length(var.wireguard_source_ranges) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 51820
  to_port           = 51820
  protocol          = "udp"
  cidr_blocks       = var.wireguard_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "WireGuard VPN peer-to-peer mesh"
}

# Ingress Kubernetes API server (6443) when control plane nodes are placed on AWS
resource "aws_security_group_rule" "kube_api" {
  count             = var.control_plane_count > 0 && length(var.kubernetes_api_source_ranges) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.kubernetes_api_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "Kubernetes API Server access"
}

# Ingress etcd (2379-2380) for multi-master cluster replication
resource "aws_security_group_rule" "etcd" {
  count             = var.control_plane_count > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  cidr_blocks       = var.cluster_source_ranges
  security_group_id = aws_security_group.worker.id
  description       = "etcd client and peer replication"
}

# Custom firewall rules matching GCP structure (e.g. HTTP 80, HTTPS 443)
locals {
  active_custom_rules = flatten([
    for rule in var.custom_firewall_rules : [
      for port in rule.ports : {
        key           = "${rule.name}-${rule.protocol}-${port}"
        name          = rule.name
        protocol      = rule.protocol
        from_port     = tonumber(split("-", port)[0])
        to_port       = length(split("-", port)) > 1 ? tonumber(split("-", port)[1]) : tonumber(split("-", port)[0])
        source_ranges = rule.source_ranges
      }
    ]
    if(
      coalesce(rule.target, "all") == "all" ||
      (coalesce(rule.target, "all") == "worker" && var.worker_count > 0) ||
      (coalesce(rule.target, "all") == "control_plane" && var.control_plane_count > 0)
    )
  ])
}

resource "aws_security_group_rule" "custom" {
  for_each = {
    for r in local.active_custom_rules :
    r.key => r
  }

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.source_ranges
  description       = "Custom rule: ${each.value.name}"
  security_group_id = aws_security_group.worker.id
}

# Outbound egress (all)
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker.id
  description       = "Allow all outbound traffic"
}

# 7. Node Planning & Selective Deletion (Concept 7)
locals {
  control_plane_nodes = var.enabled ? [
    for index in range(var.control_plane_count) : {
      name          = format("%s%02d", var.control_plane_name_prefix, index + 1 + var.control_plane_index_offset)
      instance_name = format("%s-%s%02d", var.instance_name_prefix, var.control_plane_name_prefix, index + 1 + var.control_plane_index_offset)
      role          = "control_plane"
      cloud         = "aws"
      node_index    = index
      global_index  = index + var.control_plane_index_offset
      zone          = try(local.effective_zones[index % length(local.effective_zones)], "")
      subnet_id     = try(local.az_to_subnets[local.effective_zones[index % length(local.effective_zones)]][0], "")
      machine_type = contains(var.blocked_machine_types, var.control_plane_machine_types[min(index, length(var.control_plane_machine_types) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[(index + var.control_plane_index_offset) % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.control_plane_machine_types[min(index, length(var.control_plane_machine_types) - 1)]
      root_disk_size_gb  = var.control_plane_boot_disk_size_gb
      has_secondary_disk = false
    }
  ] : []

  worker_nodes = var.enabled ? [
    for index in range(var.worker_count) : {
      name          = format("%s%02d", var.worker_name_prefix, index + 1 + var.index_offset)
      instance_name = format("%s-%s%02d", var.instance_name_prefix, var.worker_name_prefix, index + 1 + var.index_offset)
      role          = "worker"
      cloud         = "aws"
      node_index    = index
      global_index  = index + var.index_offset
      zone          = try(local.effective_zones[index % length(local.effective_zones)], "")
      subnet_id     = try(local.az_to_subnets[local.effective_zones[index % length(local.effective_zones)]][0], "")
      machine_type = contains(var.blocked_machine_types, var.worker_machine_types[min(index, length(var.worker_machine_types) - 1)]) ? (
        length(local.usable_fallback_machines) > 0 ? local.usable_fallback_machines[(index + var.index_offset) % length(local.usable_fallback_machines)] : local.default_fallback_machine
      ) : var.worker_machine_types[min(index, length(var.worker_machine_types) - 1)]
      root_disk_size_gb  = var.root_volume_size_gb
      has_secondary_disk = var.worker_data_disk_size_gb > 0
    }
  ] : []

  all_nodes         = concat(local.control_plane_nodes, local.worker_nodes)
  all_nodes_by_name = { for node in local.all_nodes : node.name => node }

  active_control_plane_nodes = var.enabled ? [
    for node in local.control_plane_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ] : []

  active_worker_nodes = var.enabled ? [
    for node in local.worker_nodes :
    node
    if !contains(var.exclude_nodes, node.instance_name)
  ] : []

  active_nodes         = concat(local.active_control_plane_nodes, local.active_worker_nodes)
  active_nodes_by_name = { for node in local.active_nodes : node.name => node }
}

# 8. Preflight Safety Preconditions (Concept 3)
resource "terraform_data" "preflight" {
  count = var.enabled && (var.worker_count + var.control_plane_count) > 0 ? 1 : 0
  input = {
    total_node_count         = var.worker_count + var.control_plane_count
    configured_zones         = local.configured_zones
    usable_zones             = local.usable_zones
    zones_with_subnets       = local.zones_with_subnets
    blocked_zones            = var.blocked_zones
    blocked_machine_types    = var.blocked_machine_types
    usable_fallback_machines = local.usable_fallback_machines
    exclude_nodes            = var.exclude_nodes
  }

  lifecycle {
    precondition {
      condition     = (var.worker_count + var.control_plane_count) == 0 || length(local.zones_with_subnets) > 0
      error_message = "No usable AWS availability zones with subnets remain. Remove entries from blocked_zones or configure more subnets."
    }

    precondition {
      condition     = length(local.usable_fallback_machines) > 0 || length(var.blocked_machine_types) == 0
      error_message = "All fallback AWS machine types are blocked. Remove entries from blocked_machine_types or add candidates to fallback_machine_types."
    }

    precondition {
      condition     = alltrue([for name in var.exclude_nodes : contains([for n in local.all_nodes : n.instance_name], name)])
      error_message = "exclude_nodes contains invalid AWS instance name(s). Valid names are: ${join(", ", [for n in local.all_nodes : n.instance_name])}"
    }

    precondition {
      condition     = alltrue([for name in var.stop_nodes : contains([for n in local.all_nodes : n.instance_name], name)])
      error_message = "stop_nodes contains invalid AWS instance name(s). Valid names are: ${join(", ", [for n in local.all_nodes : n.instance_name])}"
    }

    precondition {
      condition     = length(setintersection(toset(var.exclude_nodes), toset(var.stop_nodes))) == 0
      error_message = "A node cannot be in both exclude_nodes (delete) and stop_nodes (stop): ${join(", ", setintersection(toset(var.exclude_nodes), toset(var.stop_nodes)))}"
    }
  }
}

# 9. EC2 Instances
resource "aws_instance" "this" {
  for_each = local.active_nodes_by_name

  ami                         = local.resolved_ami_id
  instance_type               = each.value.machine_type
  subnet_id                   = each.value.subnet_id
  key_name                    = try(aws_key_pair.this[0].key_name, null)
  vpc_security_group_ids      = [aws_security_group.worker.id]
  associate_public_ip_address = true
  source_dest_check           = var.source_dest_check

  root_block_device {
    volume_size           = each.value.root_disk_size_gb
    volume_type           = var.root_volume_type
    delete_on_termination = true
    tags = merge(var.tags, {
      Name    = "${each.value.instance_name}-root"
      cluster = var.cluster_name
    })
  }

  user_data = templatefile("${path.module}/templates/user_data.tftpl", {
    ssh_user       = var.ssh_user
    ssh_public_key = var.ssh_public_key
  })

  tags = merge(var.tags, {
    Name      = each.value.instance_name
    cluster   = var.cluster_name
    role      = each.value.role
    node_name = each.value.name
    cloud     = "aws"
  })

  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  depends_on = [terraform_data.preflight]
}

# 10. Secondary EBS Volume (Concept 5: Storage Architecture)
resource "aws_ebs_volume" "data" {
  for_each = {
    for name, node in local.active_nodes_by_name :
    name => node
    if node.has_secondary_disk
  }

  availability_zone = each.value.zone
  size              = var.worker_data_disk_size_gb
  type              = var.worker_data_disk_type

  tags = merge(var.tags, {
    Name    = "${each.value.instance_name}-data"
    cluster = var.cluster_name
    role    = each.value.role
    purpose = "${each.value.role}-storage"
  })
}

resource "aws_volume_attachment" "data" {
  for_each = {
    for name, node in local.active_nodes_by_name :
    name => node
    if node.has_secondary_disk
  }

  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.data[each.key].id
  instance_id = aws_instance.this[each.key].id
}

# 11. Static Elastic IPs (Concept 4: Preserving IP across stop/start)
resource "aws_eip" "this" {
  for_each = var.allocate_elastic_ips ? local.active_nodes_by_name : {}

  domain   = "vpc"
  instance = aws_instance.this[each.key].id

  tags = merge(var.tags, {
    Name    = "${each.value.instance_name}-eip"
    cluster = var.cluster_name
    role    = each.value.role
  })

  depends_on = [aws_instance.this]
}

# 12. Power State Management (Concept 6: RUNNING vs TERMINATED)
resource "aws_ec2_instance_state" "this" {
  for_each = local.active_nodes_by_name

  instance_id = aws_instance.this[each.key].id
  state       = contains(var.stop_nodes, each.value.instance_name) || var.desired_status == "TERMINATED" ? "stopped" : "running"

  depends_on = [aws_eip.this]
}
