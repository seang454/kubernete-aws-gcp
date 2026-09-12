# AWS Kubespray Worker Nodes Module

This Terraform module provisions Kubernetes worker nodes on AWS EC2, configured for Kubespray cluster deployment.

## Features

- **Automated VPC & Subnet resolution**: Defaults to the region's default VPC and public subnets, or accepts custom VPC and subnets.
- **Multi-AZ HA distribution**: Automatically spreads worker nodes across available subnets and availability zones in round-robin order.
- **Official Ubuntu 24.04 LTS AMIs**: Dynamically finds Canonical's official Noble 24.04 LTS AMIs.
- **Static Elastic IPs**: Optionally allocates Elastic IPs so public IPs persist across VM stop/start cycles.
- **Power state management**: Supports `desired_status = "RUNNING"` or `"TERMINATED"` via `aws_ec2_instance_state`.
- **K8s & Kubespray Ready**: User-data bootstraps the SSH user, sets sudoers, enables required kernel modules (`br_netfilter`, `overlay`), and sets `net.ipv4.ip_forward=1`.
- **Selective Node Deletion**: Supports excluding specific instances using `exclude_nodes`.
- **Matching Inventory Schema**: Outputs match the schema expected by Kubespray and Ansible templates (`name`, `instance_name`, `zone`, `machine_type`, `public_ip`, `private_ip`).
