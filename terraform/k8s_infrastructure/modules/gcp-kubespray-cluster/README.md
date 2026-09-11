# GCP Kubespray Cluster Module

This module creates GCP VMs for a Kubespray cluster.

It creates:

- Control plane nodes named `master01`, `master02`, and so on in Kubespray inventory.
- Worker nodes named `worker01`, `worker02`, and so on in Kubespray inventory.
- Static external IPs for SSH.
- Internal node IPs for Kubespray `ip=...`.
- Firewall rules for SSH, internal cluster traffic, and the Kubernetes API server.

Terraform does not run Kubespray. The live root writes the generated inventory file, then you run Kubespray with Ansible.
