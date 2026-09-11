# Terraform Installation on Ubuntu/Debian

This note explains how to install Terraform on Ubuntu or Debian using the official HashiCorp package repository.

Related note: [Terraform Summary](./terraform-summary.md)

## Prerequisites

Update your system and install the required packages:

```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
```

These packages are used to verify HashiCorp's GPG signature and add the official package repository.

## Install HashiCorp's GPG Key

Download and install the HashiCorp GPG key:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```

## Verify the GPG Key

Check the GPG key fingerprint:

```bash
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint
```

The output should show HashiCorp's package signing key information, including:

```text
HashiCorp Security (HashiCorp Package Signing) <security+packaging@hashicorp.com>
```

## Add the HashiCorp Repository

Add the official HashiCorp repository to your system:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
```

## Update Package Information

Update apt so it can download package information from the HashiCorp repository:

```bash
sudo apt update
```

## Install Terraform

Install Terraform:

```bash
sudo apt-get install terraform
```

## Terraform Versions and Compatibility

HashiCorp regularly releases new Terraform versions with new features and bug fixes.

Terraform is designed to maintain compatibility between versions. A configuration written for one Terraform version should usually continue to work with later minor version updates.

## Verify the Installation

Open a new terminal session and run:

```bash
terraform -help
```

This should display Terraform usage information and a list of available subcommands.

To get help for a specific command, add `-help` after the command:

```bash
terraform plan -help
```

## Enable Tab Completion

If you use Bash or Zsh, Terraform can enable command tab completion.

For Bash, first make sure `.bashrc` exists:

```bash
touch ~/.bashrc
```

Then install Terraform autocomplete:

```bash
terraform -install-autocomplete
```

## Short Summary

To install Terraform on Ubuntu or Debian, update your system, install required packages, add HashiCorp's GPG key, add the official HashiCorp repository, update apt, and install Terraform with `apt-get`.

