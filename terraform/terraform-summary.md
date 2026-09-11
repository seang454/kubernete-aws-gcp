# Terraform Summary

## What Is Infrastructure as Code?

Infrastructure as Code, or IaC, is a way to manage infrastructure using configuration files instead of manually setting things up through a graphical user interface.

IaC helps teams build, change, and manage infrastructure in a safe, consistent, and repeatable way. Because the configuration is written as code, it can be versioned, reused, shared, and reviewed.

## What Is Terraform?

Terraform is HashiCorp's Infrastructure as Code tool. It lets you define infrastructure resources in human-readable, declarative configuration files.

With Terraform, you describe the desired final state of your infrastructure, and Terraform manages the process of creating, updating, or deleting resources to match that state.

## Why Use Terraform?

Terraform has several advantages over manually managing infrastructure:

- It can manage infrastructure across multiple cloud platforms.
- It uses a human-readable configuration language.
- It tracks infrastructure changes using a state file.
- It allows infrastructure configuration to be stored in version control.
- It supports collaboration between team members.
- It helps make deployments more consistent and repeatable.

## Manage Any Infrastructure

Terraform uses plugins called providers to communicate with cloud platforms and other services through their APIs.

Providers allow Terraform to manage resources on platforms such as:

- Amazon Web Services
- Microsoft Azure
- Google Cloud Platform
- Kubernetes
- Helm
- GitHub
- Splunk
- DataDog

Terraform has many providers available in the Terraform Registry. If a provider does not already exist, you can also create your own.

## Resources and Modules

Providers define infrastructure components as resources. Examples of resources include compute instances, databases, private networks, storage buckets, and DNS records.

Terraform configurations can combine multiple resources into reusable groups called modules. Modules help standardize infrastructure patterns and make configurations easier to reuse.

## Declarative Configuration

Terraform uses a declarative configuration language. This means you describe what infrastructure should exist, not every step needed to create it.

Terraform automatically calculates dependencies between resources and creates or destroys them in the correct order.

## Terraform Deployment Workflow

A typical Terraform workflow includes these steps:

1. Scope: Identify the infrastructure needed for the project.
2. Author: Write the Terraform configuration files.
3. Initialize: Install the required Terraform providers and plugins.
4. Plan: Preview the changes Terraform will make.
5. Apply: Apply the planned changes to create or update infrastructure.

## Terraform State

Terraform keeps track of real infrastructure using a state file. The state file acts as a source of truth for the environment Terraform manages.

Terraform compares the state file with the configuration files to decide what changes are needed.

## Collaboration

Terraform supports collaboration through remote state backends. Remote state allows team members to securely share infrastructure state and avoid conflicts when multiple people work on the same infrastructure.

HCP Terraform can also connect to version control systems such as GitHub and GitLab. This allows teams to manage infrastructure changes through commits and pull requests, similar to application code.

## Short Summary

Terraform is an Infrastructure as Code tool that helps teams define, deploy, and manage infrastructure using configuration files. It supports many cloud platforms, uses reusable modules, tracks infrastructure with state, and enables safer collaboration through version control and remote state.

## terraform-installation
[Terraform Installation](./terraform-installation.md)
## terraformCLI-Command
[terraformCLI-Command](./terraformCLI-command.md)
## terraform-reference-architecture
[terraform-reference-architecture](./terraform-reference-architecture.md)
## module-vs-live-files
[module-vs-live-files](./module-vs-live-files.md)