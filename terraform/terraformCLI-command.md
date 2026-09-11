# Terraform CLI Commands

Source: HashiCorp Developer Terraform CLI documentation.

Related notes:

- [Terraform Summary](./terraform-summary.md)
- [Terraform Installation](./terraform-installation.md)
- [Terraform Syntax Complete Guide](./Terraform%20syntax%20complete.md)

## Terraform Reference Patterns

Terraform references let you use values from variables, locals, resources, data sources, modules, and built-in Terraform objects.

The common shape is:

```hcl
THING_TYPE.NAME.ATTRIBUTE
```

Example:

```hcl
aws_instance.web.id
```

This means:

```text
Get the id attribute from the aws_instance resource named web.
```

Important: attributes such as `id`, `arn`, `public_ip`, or `result` come from the provider or resource type. You do not always write them yourself. Terraform stores them in state after reading or creating infrastructure.

| Pattern | Example | What You Get |
| --- | --- | --- |
| `var.<name>` | `var.region` | The value of an input variable. |
| `local.<name>` | `local.common_tags` | The value of a local expression. |
| `<resource_type>.<name>.<attribute>` | `aws_instance.web.id` | An attribute from a managed resource in Terraform state. |
| `data.<data_type>.<name>.<attribute>` | `data.aws_ami.ubuntu.id` | A value read from existing infrastructure or an external source. |
| `module.<name>.<output>` | `module.vpc.vpc_id` | An output value from a child module. |
| `<resource_type>.<name>[0].<attribute>` | `aws_instance.web[0].id` | An attribute from one resource created with `count`. |
| `<resource_type>.<name>["key"].<attribute>` | `aws_instance.server["app"].id` | An attribute from one resource created with `for_each`. |
| `<resource_type>.<name>[*].<attribute>` | `aws_instance.web[*].public_ip` | A list of one attribute from all instances of a resource. |
| `each.key` | `each.key` | The current key inside a `for_each` block. |
| `each.value` | `each.value` | The current value inside a `for_each` block. |
| `count.index` | `count.index` | The current numeric index inside a `count` block. |
| `self.<attribute>` | `self.id` | The current resource inside a provisioner, precondition, or postcondition. |
| `path.module` | `path.module` | The filesystem path of the current module. |
| `path.root` | `path.root` | The filesystem path of the root module. |
| `path.cwd` | `path.cwd` | The directory where Terraform was started. |
| `terraform.workspace` | `terraform.workspace` | The currently selected Terraform workspace name. |
| `<resource_type>.<name>.result` | `random_password.db.result` | A generated or calculated result from a resource that provides a `result` attribute. |
| `terraform_data.<name>.output` | `terraform_data.setup.output` | The output value stored by a `terraform_data` resource. |
| `ephemeral.<type>.<name>.<attribute>` | `ephemeral.random_password.db.result` | A temporary value that is not stored in Terraform state, when supported. |

### Variable Reference

Define:

```hcl
variable "region" {
  type    = string
  default = "us-east-1"
}
```

Use:

```hcl
provider "aws" {
  region = var.region
}
```

Result:

```text
var.region -> "us-east-1"
```

### Local Reference

Define:

```hcl
locals {
  name_prefix = "dev-app"
}
```

Use:

```hcl
name = local.name_prefix
```

Result:

```text
local.name_prefix -> "dev-app"
```

### Resource Attribute Reference

Define:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-123456"
  instance_type = "t3.micro"
}
```

Use:

```hcl
aws_instance.web.id
aws_instance.web.public_ip
```

Result after apply:

```text
aws_instance.web.id        -> EC2 instance ID, such as i-0123456789abcdef0
aws_instance.web.public_ip -> Public IP address, such as 18.10.20.30
```

### Data Source Reference

Define:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
}
```

Use:

```hcl
data.aws_ami.ubuntu.id
```

Result:

```text
data.aws_ami.ubuntu.id -> AMI ID found by the data source
```

### Module Output Reference

Child module output:

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}
```

Parent module use:

```hcl
module.vpc.vpc_id
```

Result:

```text
module.vpc.vpc_id -> The VPC ID returned by the child module
```

### Count Resource Reference

Define:

```hcl
resource "aws_instance" "web" {
  count = 2

  ami           = var.ami_id
  instance_type = "t3.micro"
}
```

Use:

```hcl
aws_instance.web[0].id
aws_instance.web[1].id
aws_instance.web[*].id
```

Result:

```text
aws_instance.web[0].id -> ID of the first instance
aws_instance.web[1].id -> ID of the second instance
aws_instance.web[*].id -> List of all instance IDs
```

### for_each Resource Reference

Define:

```hcl
resource "aws_instance" "server" {
  for_each = {
    app = "t3.micro"
    db  = "t3.small"
  }

  ami           = var.ami_id
  instance_type = each.value

  tags = {
    Name = each.key
  }
}
```

Use:

```hcl
aws_instance.server["app"].id
aws_instance.server["db"].id
```

Result:

```text
aws_instance.server["app"].id -> ID of the app instance
aws_instance.server["db"].id  -> ID of the db instance
```

Inside the block:

```text
each.key   -> "app" or "db"
each.value -> "t3.micro" or "t3.small"
```

### Result Attribute

Some resources generate a value and expose it as `.result`.

Define:

```hcl
resource "random_password" "db" {
  length  = 16
  special = true
}
```

Use:

```hcl
random_password.db.result
```

Result:

```text
random_password.db.result -> The generated password string
```

Note: `.result` is not available on every resource. It only exists when the provider documentation says that resource has a `result` attribute.

### Path and Workspace References

```hcl
path.module
path.root
path.cwd
terraform.workspace
```

Result:

```text
path.module         -> Current module directory
path.root           -> Root module directory
path.cwd            -> Directory where Terraform command was run
terraform.workspace -> Current workspace, usually "default" unless changed
```

## What Is Terraform CLI?

Terraform CLI is the command-line tool used to initialize Terraform projects, validate configuration, preview infrastructure changes, apply changes, inspect state, manage providers, import existing resources, and work with Terraform Cloud or HCP Terraform.

General syntax:

```bash
terraform [global options] <command> [arguments]
```

Common global options:

```bash
terraform -help
terraform -version
terraform -chdir=DIR <command>
```

`-chdir=DIR` tells Terraform to switch to another directory before running the command.

## Main Workflow Commands

### terraform init

Initializes a Terraform working directory. This is usually the first command you run after creating or cloning Terraform configuration.

It downloads providers, installs modules, configures the backend, and creates local Terraform metadata such as the `.terraform` directory and lock file.

Example:

```bash
terraform init
```

Common options:

```bash
terraform init -upgrade
terraform init -backend=false
terraform init -reconfigure
```

Use it when:

- You create a new Terraform project.
- You clone an existing Terraform project.
- You change providers, modules, or backend settings.

### terraform plan

Creates an execution plan. It shows what Terraform will create, update, replace, or destroy before making real changes.

Example:

```bash
terraform plan
```

Save a plan to a file:

```bash
terraform plan -out=tfplan
```

Use it when:

- You want to preview infrastructure changes.
- You want to review changes before applying.
- You want to use the same saved plan later with `terraform apply`.

### terraform apply

Applies the changes required to make real infrastructure match the Terraform configuration.

Example:

```bash
terraform apply
```

Apply a saved plan:

```bash
terraform apply tfplan
```

Skip manual approval:

```bash
terraform apply -auto-approve
```

Use it when:

- You are ready to create or update infrastructure.
- You have reviewed the plan and want Terraform to execute it.

### terraform destroy

Destroys infrastructure managed by Terraform.

Example:

```bash
terraform destroy
```

Skip manual approval:

```bash
terraform destroy -auto-approve
```

Use it carefully when:

- You want to remove an environment.
- You want to clean up test infrastructure.

## Initializing Working Directories

### terraform init

Prepares the working directory for Terraform commands.

```bash
terraform init
```

### terraform get

Downloads or updates modules used by the current Terraform configuration.

Example:

```bash
terraform get
```

Update modules:

```bash
terraform get -update
```

Use it when:

- Your configuration uses remote modules.
- You changed module sources.
- You want to update downloaded modules.

## Authenticating

### terraform login

Authenticates Terraform CLI with a remote host such as HCP Terraform.

Example:

```bash
terraform login
```

Use it when:

- You need Terraform CLI to access HCP Terraform.
- You need to save an API token locally for a Terraform service host.

### terraform logout

Removes locally stored credentials for a remote host.

Example:

```bash
terraform logout
```

Use it when:

- You want to remove saved HCP Terraform credentials.
- You are switching accounts.

## Writing and Modifying Code

### terraform console

Opens an interactive console for testing Terraform expressions.

Example:

```bash
terraform console
```

Inside the console:

```hcl
> upper("terraform")
"TERRAFORM"
```

Use it when:

- You want to test expressions.
- You want to inspect values.
- You are debugging variables, locals, or functions.

### terraform fmt

Formats Terraform configuration files into the standard style.

Example:

```bash
terraform fmt
```

Format files recursively:

```bash
terraform fmt -recursive
```

Check formatting without changing files:

```bash
terraform fmt -check
```

Use it when:

- You want consistent Terraform code style.
- You are preparing code for commit or review.

### terraform validate

Checks whether Terraform configuration is syntactically valid and internally consistent.

Example:

```bash
terraform validate
```

Use it when:

- You want to check configuration before planning.
- You want to test reusable modules.
- You want a CI check for Terraform code.

Note: `validate` checks configuration structure. It does not check whether cloud credentials are valid or whether remote APIs will accept the changes.

## Inspecting Infrastructure

### terraform graph

Generates a dependency graph of Terraform resources.

Example:

```bash
terraform graph
```

Save graph output:

```bash
terraform graph > graph.dot
```

Use it when:

- You want to understand resource dependencies.
- You want to visualize how Terraform orders operations.

### terraform output

Displays output values from the root module.

Example:

```bash
terraform output
```

Show one output:

```bash
terraform output instance_ip
```

Use JSON output:

```bash
terraform output -json
```

Use it when:

- You need values produced by Terraform.
- You want to pass Terraform outputs into scripts or automation.

### terraform show

Shows human-readable information from current state or a saved plan.

Example:

```bash
terraform show
```

Show a saved plan:

```bash
terraform show tfplan
```

JSON output:

```bash
terraform show -json
```

Use it when:

- You want to inspect current Terraform state.
- You want to review a saved plan file.

### terraform state list

Lists resources tracked in Terraform state.

Example:

```bash
terraform state list
```

Use it when:

- You want to see which resources Terraform manages.
- You need a resource address for another state command.

### terraform state show

Shows detailed state information for one resource.

Example:

```bash
terraform state show aws_instance.web
```

Use it when:

- You need details about a tracked resource.
- You want to compare state data with real infrastructure.

## Import Infrastructure

### terraform import

Associates an existing real-world resource with a Terraform resource address in state.

Example:

```bash
terraform import aws_instance.web i-1234567890abcdef0
```

Use it when:

- A resource already exists outside Terraform.
- You want Terraform to start managing that resource.

Important: Before using the CLI import command, you usually write the matching `resource` block manually. The command imports the resource into state, but does not automatically create full configuration for every use case.

### terraform query

Queries existing infrastructure based on `.tfquery.hcl` files so Terraform can help discover resources for import.

Example:

```bash
terraform query
```

Generate configuration output:

```bash
terraform query -generate-config-out=generated.tf
```

Use it when:

- You want to discover existing infrastructure.
- You want help preparing bulk import workflows.

## Manually Updating State

### terraform state

Parent command for advanced state management.

Example:

```bash
terraform state
```

Use it when:

- You need to inspect or modify Terraform state directly.
- You are repairing, moving, removing, or migrating state records.

Be careful: state commands can change Terraform's understanding of your infrastructure.

### Resource Addressing

A resource address identifies a resource in Terraform configuration and state.

Examples:

```bash
aws_instance.web
module.network.aws_vpc.main
aws_instance.web[0]
aws_instance.web["example"]
```

Resource addresses are used by commands such as:

```bash
terraform state show
terraform state mv
terraform import
terraform taint
```

## Inspecting State

### terraform state list

Lists resources in state.

```bash
terraform state list
```

### terraform state show

Shows state details for one resource.

```bash
terraform state show aws_instance.web
```

### terraform refresh

Updates Terraform state to match real remote infrastructure.

Example:

```bash
terraform refresh
```

Use it when:

- You want Terraform state to reflect current remote objects.

Note: In modern Terraform workflows, `terraform plan` normally includes refresh behavior. `terraform refresh` is less commonly used directly.

## Forcing Re-creation

### terraform taint

Marks a resource instance as tainted, meaning Terraform should replace it on the next apply.

Example:

```bash
terraform taint aws_instance.web
```

Use it when:

- A resource is damaged or misconfigured.
- You want Terraform to recreate it.

Note: Newer workflows often prefer `terraform apply -replace=RESOURCE`.

### terraform untaint

Removes the tainted mark from a resource.

Example:

```bash
terraform untaint aws_instance.web
```

Use it when:

- A resource was marked for replacement but should not be replaced anymore.

## Moving Resources

### terraform state mv

Moves a resource address inside Terraform state.

Example:

```bash
terraform state mv aws_instance.old aws_instance.new
```

Use it when:

- You rename a resource in configuration.
- You move a resource into or out of a module.
- You want to avoid destroying and recreating a resource after refactoring code.

### terraform state rm

Removes a resource from Terraform state without destroying the real infrastructure.

Example:

```bash
terraform state rm aws_instance.web
```

Use it when:

- Terraform should stop managing a resource.
- You need to detach a resource from Terraform state.

Important: This does not delete the actual cloud resource.

### terraform state replace-provider

Replaces provider references in Terraform state.

Example:

```bash
terraform state replace-provider registry.terraform.io/hashicorp/aws registry.example.com/example/aws
```

Use it when:

- You migrate resources from one provider source address to another.
- A provider namespace or source address changes.

## Disaster Recovery

### terraform state pull

Downloads and prints the current state from the backend.

Example:

```bash
terraform state pull
```

Save state to a file:

```bash
terraform state pull > terraform.tfstate.backup
```

Use it when:

- You need a backup copy of remote state.
- You need to inspect raw state JSON.

### terraform state push

Uploads a local state file to the configured backend.

Example:

```bash
terraform state push terraform.tfstate
```

Use it when:

- You need to restore or repair state.
- You are recovering from a backend/state problem.

Important: Use carefully. Pushing incorrect state can damage Terraform's view of your infrastructure.

### terraform force-unlock

Manually releases a stuck Terraform state lock.

Example:

```bash
terraform force-unlock LOCK_ID
```

Use it when:

- A previous Terraform operation crashed.
- The state lock remains stuck.

Important: Only unlock when you are sure no Terraform operation is still running.

## Managing Workspaces

### terraform workspace

Parent command for CLI workspace management.

```bash
terraform workspace
```

Terraform CLI workspaces are separate state instances for the same configuration directory.

### terraform workspace list

Lists available workspaces.

```bash
terraform workspace list
```

### terraform workspace show

Shows the currently selected workspace.

```bash
terraform workspace show
```

### terraform workspace new

Creates and switches to a new workspace.

```bash
terraform workspace new dev
```

### terraform workspace select

Switches to an existing workspace.

```bash
terraform workspace select dev
```

Create it if missing:

```bash
terraform workspace select -or-create dev
```

### terraform workspace delete

Deletes a workspace.

```bash
terraform workspace delete dev
```

Use workspaces when:

- You need separate state for the same configuration.
- You want simple environment separation, such as `dev` and `test`.

Note: For complex production environments, separate directories, separate backends, or HCP Terraform workspaces may be better.

## Managing Plugins and Providers

### terraform providers

Shows provider requirements for the current configuration.

```bash
terraform providers
```

Use it when:

- You want to see which providers your configuration needs.
- You are debugging provider dependencies across modules.

### terraform providers lock

Creates or updates dependency lock information for providers.

```bash
terraform providers lock
```

Use it when:

- You want consistent provider versions.
- You need provider checksums for specific platforms.

### terraform providers mirror

Downloads provider packages into a local filesystem mirror.

```bash
terraform providers mirror ./provider-mirror
```

Use it when:

- You need offline provider installation.
- You want an internal provider mirror.

### terraform providers schema

Prints provider schemas.

```bash
terraform providers schema
```

JSON output:

```bash
terraform providers schema -json
```

Use it when:

- You are inspecting provider resource types.
- You are building tooling around Terraform providers.

### terraform version

Shows the Terraform CLI version and provider version information.

```bash
terraform version
```

## CLI Configuration

Terraform CLI can use a CLI configuration file to customize local CLI behavior.

Common uses:

- Configure provider installation methods.
- Configure plugin cache directories.
- Store credentials for Terraform service hosts.

Environment variables can also change Terraform behavior.

Common examples:

```bash
TF_LOG=DEBUG
TF_VAR_region=us-east-1
TF_CLI_CONFIG_FILE=/path/to/config.tfrc
```

## Using HCP Terraform

Terraform CLI can connect to HCP Terraform for remote operations, state management, collaboration, and VCS-driven workflows.

Useful commands:

```bash
terraform login
terraform logout
terraform init
terraform plan
terraform apply
```

Use it when:

- Your backend or cloud block connects the project to HCP Terraform.
- Your team wants remote state, remote runs, policy checks, and collaboration features.

## Testing Terraform

### terraform test

Runs Terraform tests written for modules and configurations.

Example:

```bash
terraform test
```

Use it when:

- You want to test Terraform modules.
- You want automated checks for infrastructure code behavior.

## Automating Terraform

Terraform can run in automation systems such as CI/CD pipelines and GitHub Actions.

Common automation flow:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply -auto-approve
```

Automation best practices:

- Use remote state.
- Lock state during runs.
- Store credentials securely.
- Review plans before applying in production.
- Avoid multiple concurrent applies to the same workspace.

## Manage Stacks

Terraform Stacks are used to manage groups of infrastructure deployments, usually with HCP Terraform.

### terraform stacks

Parent command for Terraform Stacks.

```bash
terraform stacks
```

Use it when:

- You are working with Terraform Stack configurations.
- You need to manage Stack deployments through HCP Terraform.

### terraform stacks init

Initializes a Stack configuration directory.

```bash
terraform stacks init
```

### terraform stacks validate

Checks whether Stack component and deployment configurations are valid.

```bash
terraform stacks validate
```

### terraform stacks fmt

Formats Stack component and deployment configuration files.

```bash
terraform stacks fmt
```

### terraform stacks create

Creates a Stack in HCP Terraform.

```bash
terraform stacks create
```

### terraform stacks list

Lists Stacks for an organization or project.

```bash
terraform stacks list
```

### terraform stacks providers-lock

Writes dependency lock information for providers used by a Stack.

```bash
terraform stacks providers-lock
```

### terraform stacks version

Shows the current Stacks plugin version.

```bash
terraform stacks version
```

## Stacks Configuration Commands

### terraform stacks configuration fetch

Fetches Stack configuration version information.

```bash
terraform stacks configuration fetch
```

### terraform stacks configuration list

Lists Stack configuration versions.

```bash
terraform stacks configuration list
```

### terraform stacks configuration upload

Uploads a Stack configuration version.

```bash
terraform stacks configuration upload
```

### terraform stacks configuration watch

Watches a Stack configuration rollout.

```bash
terraform stacks configuration watch
```

## Stacks Deployment Group Commands

### terraform stacks deployment-group list

Lists deployment groups for a Stack.

```bash
terraform stacks deployment-group list
```

### terraform stacks deployment-group approve-all-plans

Approves all plans in a deployment group that are waiting for approval.

```bash
terraform stacks deployment-group approve-all-plans
```

### terraform stacks deployment-group rerun

Reruns deployment group operations.

```bash
terraform stacks deployment-group rerun
```

### terraform stacks deployment-group watch

Watches deployment group progress.

```bash
terraform stacks deployment-group watch
```

## Stacks Deployment Run Commands

### terraform stacks deployment-run list

Lists deployment runs.

```bash
terraform stacks deployment-run list
```

### terraform stacks deployment-run approve-all-plans

Approves all plans in a deployment run that are waiting for approval.

```bash
terraform stacks deployment-run approve-all-plans
```

### terraform stacks deployment-run cancel

Cancels a deployment run.

```bash
terraform stacks deployment-run cancel
```

### terraform stacks deployment-run watch

Watches a deployment run.

```bash
terraform stacks deployment-run watch
```

## Alphabetical Command Summary

| Command | Purpose |
| --- | --- |
| `terraform apply` | Applies planned infrastructure changes. |
| `terraform console` | Opens an interactive Terraform expression console. |
| `terraform destroy` | Destroys Terraform-managed infrastructure. |
| `terraform fmt` | Formats Terraform configuration files. |
| `terraform force-unlock` | Releases a stuck state lock. |
| `terraform get` | Downloads or updates modules. |
| `terraform graph` | Generates a dependency graph. |
| `terraform import` | Imports existing infrastructure into state. |
| `terraform init` | Initializes a working directory. |
| `terraform login` | Saves credentials for a remote Terraform service host. |
| `terraform logout` | Removes saved credentials. |
| `terraform modules` | Shows modules declared in the working directory. |
| `terraform output` | Displays root module outputs. |
| `terraform plan` | Previews infrastructure changes. |
| `terraform providers` | Shows provider requirements. |
| `terraform providers lock` | Updates provider lock information. |
| `terraform providers mirror` | Creates a local provider mirror. |
| `terraform providers schema` | Prints provider schemas. |
| `terraform query` | Queries existing infrastructure for import workflows. |
| `terraform refresh` | Updates state from remote infrastructure. |
| `terraform show` | Shows state or saved plan details. |
| `terraform state` | Parent command for state management. |
| `terraform state list` | Lists resources in state. |
| `terraform state mv` | Moves resource addresses in state. |
| `terraform state pull` | Downloads state from the backend. |
| `terraform state push` | Uploads local state to the backend. |
| `terraform state replace-provider` | Replaces provider addresses in state. |
| `terraform state rm` | Removes resources from state only. |
| `terraform state show` | Shows one resource from state. |
| `terraform taint` | Marks a resource for replacement. |
| `terraform test` | Runs Terraform tests. |
| `terraform untaint` | Removes tainted status. |
| `terraform validate` | Validates configuration syntax and consistency. |
| `terraform version` | Shows Terraform version. |
| `terraform workspace` | Parent command for workspace management. |
| `terraform workspace delete` | Deletes a workspace. |
| `terraform workspace list` | Lists workspaces. |
| `terraform workspace new` | Creates a workspace. |
| `terraform workspace select` | Selects a workspace. |
| `terraform workspace show` | Shows the current workspace. |

## Quick Beginner Workflow

For most basic Terraform projects, the common workflow is:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
```

To remove the infrastructure later:

```bash
terraform destroy
```

## References

- HashiCorp Developer: Terraform CLI Overview: https://developer.hashicorp.com/terraform/cli/commands
- HashiCorp Developer: `terraform init`: https://developer.hashicorp.com/terraform/cli/commands/init
- HashiCorp Developer: `terraform plan`: https://developer.hashicorp.com/terraform/cli/commands/plan
- HashiCorp Developer: `terraform apply`: https://developer.hashicorp.com/terraform/cli/commands/apply
- HashiCorp Developer: `terraform validate`: https://developer.hashicorp.com/terraform/cli/commands/validate
- HashiCorp Developer: `terraform fmt`: https://developer.hashicorp.com/terraform/cli/commands/fmt
- HashiCorp Developer: `terraform import`: https://developer.hashicorp.com/terraform/cli/commands/import
- HashiCorp Developer: `terraform query`: https://developer.hashicorp.com/terraform/cli/commands/query
- HashiCorp Developer: Terraform State Commands: https://developer.hashicorp.com/terraform/cli/commands/state
- HashiCorp Developer: Terraform Workspaces: https://developer.hashicorp.com/terraform/cli/workspaces
- HashiCorp Developer: Terraform Stacks Commands: https://developer.hashicorp.com/terraform/cli/commands/stacks
