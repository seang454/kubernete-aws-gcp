# Terraform Syntax Complete Guide

This file is a study guide for Terraform HCL syntax. HCL means HashiCorp Configuration Language. Terraform uses it to describe providers, resources, variables, modules, state backends, tests, and other infrastructure behavior.

Official reference links are listed at the end of this file.

Related notes:

- [Terraform Summary](./terraform-summary.md)
- [Terraform Installation](./terraform-installation.md)
- [Terraform CLI Commands](./terraformCLI-command.md)

## Table of Contents

1. [Terraform File Types](#1-terraform-file-types)
2. [Basic HCL Syntax](#2-basic-hcl-syntax)
3. [Values and Type System](#3-values-and-type-system)
4. [Expressions](#4-expressions)
5. [Top-Level Blocks](#5-top-level-blocks)
6. [Meta-Arguments](#6-meta-arguments)
7. [Nested Blocks](#7-nested-blocks)
8. [Functions](#8-functions)
9. [Variables and tfvars](#9-variables-and-tfvars)
10. [State, Backend, and Workspaces](#10-state-backend-and-workspaces)
11. [Testing Syntax](#11-testing-syntax)
12. [JSON Terraform Syntax](#12-json-terraform-syntax)
13. [Common Patterns](#13-common-patterns)
14. [Complete Example](#14-complete-example)
15. [Quick Cheat Sheet](#15-quick-cheat-sheet)
16. [Official References](#16-official-references)

## 1. Terraform File Types

Terraform reads all `.tf` files in the current module directory and treats them as one combined configuration.

Common file names:

```text
main.tf              Main resources
variables.tf         Input variables
outputs.tf           Output values
locals.tf            Local computed values
providers.tf         Provider configuration
versions.tf          Terraform and provider versions
backend.tf           State backend configuration
data.tf              Data sources
terraform.tfvars     Variable values, auto-loaded
*.auto.tfvars        Variable values, auto-loaded alphabetically
*.tftest.hcl         Terraform test files
```

File name is a convention. Terraform does not require `main.tf`, `variables.tf`, or `outputs.tf`; it only requires valid `.tf` syntax.

Terraform also supports JSON configuration:

```text
main.tf.json
variables.tf.json
tests/example.tftest.json
```

Use normal `.tf` files for learning and daily work. Use `.tf.json` only when generating Terraform from another program.

## 2. Basic HCL Syntax

Terraform syntax is built from two main things:

- Arguments: assign a value to a name.
- Blocks: group related arguments and nested blocks.

### Argument Syntax

```hcl
name = "value"
port = 9000
enabled = true
```

General pattern:

```hcl
IDENTIFIER = EXPRESSION
```

### Block Syntax

```hcl
resource "aws_instance" "web" {
  ami           = "ami-123456"
  instance_type = "t3.micro"
}
```

General pattern:

```hcl
BLOCK_TYPE "LABEL_1" "LABEL_2" {
  argument = value

  nested_block {
    argument = value
  }
}
```

### Comments

```hcl
# Most common single-line comment

// Also valid single-line comment

/*
Multi-line comment
*/
```

### Strings

Terraform strings use double quotes.

```hcl
name = "sonarqube"
```

Single quotes are invalid:

```hcl
# Wrong
name = 'sonarqube'
```

### Formatting

Use:

```bash
terraform fmt
```

Terraform formatting conventions:

- 2 spaces for indentation.
- Align related arguments when `terraform fmt` does it.
- Keep blocks readable.
- Put meta-arguments near the top of a block.

## 3. Values and Type System

Terraform has primitive types, collection types, structural types, and special values.

### Primitive Types

```hcl
string_value = "hello"
number_value = 42
float_value  = 3.14
bool_value   = true
```

Primitive type constraints:

```hcl
type = string
type = number
type = bool
```

### Null

`null` means "unset" or "omit this value".

```hcl
variable "description" {
  type    = string
  default = null
}
```

This is useful for optional provider arguments.

### List

A list is ordered and allows duplicates.

```hcl
availability_zones = ["us-east-1a", "us-east-1b"]
```

Type:

```hcl
type = list(string)
```

Access:

```hcl
var.availability_zones[0]
```

### Set

A set is unordered and unique.

```hcl
enabled_regions = toset(["us-east-1", "us-west-2"])
```

Type:

```hcl
type = set(string)
```

Use sets with `for_each` when you only need unique values.

### Map

A map is a key-value collection where all values have the same type.

```hcl
tags = {
  Environment = "dev"
  Owner       = "platform"
}
```

Type:

```hcl
type = map(string)
```

Access:

```hcl
var.tags["Environment"]
var.tags.Environment
```

Use bracket syntax when the key has special characters.

### Object

An object has named attributes. Each attribute can have a different type.

```hcl
variable "server" {
  type = object({
    name      = string
    cpu       = number
    memory_gb = number
    public    = bool
  })
}
```

Example value:

```hcl
server = {
  name      = "app-01"
  cpu       = 2
  memory_gb = 4
  public    = false
}
```

### Optional Object Attributes

Use `optional()` for object attributes that callers may omit.

```hcl
variable "server" {
  type = object({
    name        = string
    size        = optional(string, "small")
    description = optional(string)
  })
}
```

Meaning:

- `name` is required.
- `size` is optional and defaults to `"small"`.
- `description` is optional and defaults to `null`.

### Tuple

A tuple is an ordered fixed-length collection where each position has its own type.

```hcl
type = tuple([string, number, bool])
```

Example:

```hcl
example = ["web", 2, true]
```

Use tuple rarely. Most module inputs should use `list(...)` or `object(...)`.

### Any

`any` allows Terraform to infer the type.

```hcl
variable "raw_config" {
  type = any
}
```

Use `any` carefully. Specific types are easier to validate and understand.

### Complex Type Examples

List of objects:

```hcl
variable "servers" {
  type = list(object({
    name = string
    port = number
  }))
}
```

Map of objects:

```hcl
variable "instances" {
  type = map(object({
    instance_type = string
    subnet_id     = string
    enabled       = optional(bool, true)
  }))
}
```

Map of list:

```hcl
variable "security_groups" {
  type = map(list(string))
}
```

## 4. Expressions

Expressions calculate values. They appear on the right side of arguments.

### Literal Expressions

```hcl
"hello"
123
true
null
["a", "b"]
{ name = "web" }
```

### References

```hcl
var.environment
local.common_tags
aws_instance.web.id
data.aws_ami.ubuntu.id
module.vpc.vpc_id
terraform.workspace
path.module
path.root
path.cwd
```

### String Interpolation

```hcl
name = "app-${var.environment}"
```

Interpolation can call functions:

```hcl
name = "app-${lower(var.environment)}"
```

When the whole string is only one expression, prefer direct expression syntax:

```hcl
# Better
name = var.name

# Works, but unnecessary
name = "${var.name}"
```

Escape literal interpolation:

```hcl
text = "Print literal $${var.name}"
```

### Heredoc Strings

Standard heredoc:

```hcl
user_data = <<EOF
#!/bin/bash
echo "Hello"
EOF
```

Indented heredoc:

```hcl
user_data = <<-EOF
  #!/bin/bash
  echo "Hello"
EOF
```

### Operators

Arithmetic:

```hcl
1 + 2
5 - 3
2 * 4
10 / 2
10 % 3
```

Comparison:

```hcl
var.env == "prod"
var.size != "small"
var.count > 0
var.count <= 5
```

Logical:

```hcl
var.enabled && var.env == "prod"
var.enabled || var.force
!var.disabled
```

### Conditional Expression

Syntax:

```hcl
condition ? true_value : false_value
```

Example:

```hcl
instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
```

Conditional resource:

```hcl
count = var.enabled ? 1 : 0
```

Both result values should have compatible types.

### For Expressions

List from list:

```hcl
[for name in var.names : upper(name)]
```

List with filter:

```hcl
[for name in var.names : name if startswith(name, "prod")]
```

Map from list:

```hcl
{ for name in var.names : name => upper(name) }
```

Map from map:

```hcl
{ for key, value in var.tags : key => upper(value) }
```

Group values with `...`:

```hcl
{ for user in var.users : user.role => user.name... }
```

### Splat Expressions

Get one attribute from all instances:

```hcl
aws_instance.web[*].public_ip
```

Equivalent for expression:

```hcl
[for instance in aws_instance.web : instance.public_ip]
```

### Dynamic Blocks

Use `dynamic` when a resource has repeatable nested blocks.

```hcl
resource "aws_security_group" "web" {
  name = "web"

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

Dynamic block fields:

```hcl
dynamic "BLOCK_NAME" {
  for_each = COLLECTION
  iterator = custom_name # optional
  labels   = []          # optional, for blocks with labels

  content {
    # nested block body
  }
}
```

## 5. Top-Level Blocks

Top-level blocks are blocks that can appear directly in a `.tf` file.

### terraform

The `terraform` block configures Terraform itself.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/main.tfstate"
    region = "us-east-1"
  }
}
```

Supported nested blocks include:

- `required_providers`
- `backend`
- `cloud`
- `provider_meta`
- experimental feature settings when Terraform documents them

### provider

The `provider` block configures a provider plugin.

```hcl
provider "aws" {
  region = "us-east-1"
}
```

Provider alias:

```hcl
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}
```

Use aliased provider:

```hcl
resource "aws_s3_bucket" "logs" {
  provider = aws.west
  bucket   = "example-logs"
}
```

### resource

The `resource` block creates and manages infrastructure.

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "company-prod-logs"
}
```

Pattern:

```hcl
resource "RESOURCE_TYPE" "LOCAL_NAME" {
  argument = value
}
```

Reference:

```hcl
aws_s3_bucket.logs.id
```

### data

The `data` block reads existing information without creating infrastructure.

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

Reference:

```hcl
data.aws_ami.ubuntu.id
```

### ephemeral

The `ephemeral` block defines temporary provider resources that Terraform does not store in plan or state files. Use it for short-lived or sensitive values when the provider supports it.

```hcl
ephemeral "random_password" "db" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
```

Reference only in allowed ephemeral contexts:

```hcl
ephemeral.random_password.db.result
```

Common use with write-only provider arguments:

```hcl
resource "aws_db_instance" "main" {
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  engine              = "postgres"
  username            = "app"
  skip_final_snapshot = true

  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1
}
```

Notes:

- `ephemeral` requires provider support.
- Ephemeral values are not persisted to state or plan.
- Terraform v1.10+ introduced ephemeral resources.
- Write-only arguments require Terraform v1.11+ and provider support.

### action

The `action` block configures provider-defined operations that can be invoked manually or triggered from a resource lifecycle. Use it for operations that are not normal create, read, update, delete resources.

```hcl
action "aws_lambda_invoke" "restart_job" {
  config {
    function_name = aws_lambda_function.worker.function_name
    payload       = jsonencode({ reason = "terraform" })
  }
}
```

Manual invocation:

```bash
terraform apply -invoke=action.aws_lambda_invoke.restart_job
```

Actions require provider support. Terraform actions are a newer language feature, so always check your Terraform and provider versions.

### variable

The `variable` block declares an input.

```hcl
variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
  nullable    = false
  sensitive   = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
```

Variable arguments:

- `description`
- `type`
- `default`
- `sensitive`
- `nullable`
- `ephemeral`
- `validation`

Ephemeral variable example:

```hcl
variable "session_token" {
  type      = string
  sensitive = true
  ephemeral = true
}
```

### output

The `output` block returns values from a module.

```hcl
output "instance_ip" {
  description = "Public IP address."
  value       = aws_instance.web.public_ip
  sensitive   = false
}
```

Output with precondition:

```hcl
output "api_endpoint" {
  value = "https://${aws_lb.app.dns_name}"

  precondition {
    condition     = aws_lb.app.dns_name != ""
    error_message = "Load balancer DNS name is empty."
  }
}
```

Ephemeral output example:

```hcl
output "temporary_token" {
  value     = var.session_token
  sensitive = true
  ephemeral = true
}
```

### locals

The `locals` block defines named expressions inside the module.

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

Reference:

```hcl
local.common_tags
```

### module

The `module` block calls another Terraform module.

```hcl
module "vpc" {
  source = "./modules/vpc"

  name       = "main"
  cidr_block = "10.0.0.0/16"
}
```

Registry module:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "main"
  cidr = "10.0.0.0/16"
}
```

Git module:

```hcl
module "app" {
  source = "git::https://github.com/example/terraform-app.git?ref=v1.0.0"
}
```

Pass provider aliases:

```hcl
module "logs" {
  source = "./modules/logs"

  providers = {
    aws = aws.west
  }
}
```

### import

The `import` block imports existing infrastructure into Terraform state.

```hcl
import {
  to = aws_instance.web
  id = "i-1234567890abcdef0"
}
```

Then run:

```bash
terraform plan
terraform apply
```

### moved

The `moved` block renames or moves resources without destroying them.

```hcl
moved {
  from = aws_instance.old
  to   = aws_instance.new
}
```

Move into a module:

```hcl
moved {
  from = aws_instance.web
  to   = module.app.aws_instance.web
}
```

### removed

The `removed` block removes a resource from state. Set `destroy = false` when you want Terraform to stop managing the object but leave the real infrastructure running.

```hcl
removed {
  from = aws_instance.old

  lifecycle {
    destroy = false
  }
}
```

Set `destroy = true` if you want Terraform to destroy the object while removing it from the configuration.

### check

The `check` block validates infrastructure after Terraform evaluates the configuration. Failed checks produce warnings, not hard failures.

```hcl
check "website_health" {
  data "http" "site" {
    url = "https://${aws_lb.app.dns_name}"
  }

  assert {
    condition     = data.http.site.status_code == 200
    error_message = "Website did not return HTTP 200."
  }
}
```

Use `check` for health and validation checks that should be visible but should not block all infrastructure changes.

## 6. Meta-Arguments

Meta-arguments are built into Terraform. They control resource, module, data, ephemeral, or action behavior depending on block type.

### count

Create multiple instances by number.

```hcl
resource "aws_instance" "web" {
  count = 3

  ami           = var.ami_id
  instance_type = "t3.micro"
  tags = {
    Name = "web-${count.index}"
  }
}
```

Reference:

```hcl
aws_instance.web[0].id
aws_instance.web[*].id
```

Conditional creation:

```hcl
count = var.enabled ? 1 : 0
```

### for_each

Create instances from a map or set.

```hcl
resource "aws_iam_user" "users" {
  for_each = toset(["alice", "bob"])

  name = each.key
}
```

Map example:

```hcl
resource "aws_instance" "servers" {
  for_each = var.instances

  ami           = var.ami_id
  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id

  tags = {
    Name = each.key
  }
}
```

Reference:

```hcl
aws_instance.servers["web"].id
```

Use `for_each` instead of `count` when each instance has a stable name.

### depends_on

Force an explicit dependency.

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  depends_on = [aws_security_group.app]
}
```

Terraform normally detects dependencies from references. Use `depends_on` only when Terraform cannot see the dependency through an expression.

### provider

Select a provider configuration.

```hcl
resource "aws_s3_bucket" "logs" {
  provider = aws.west
  bucket   = "company-west-logs"
}
```

### lifecycle

The `lifecycle` block customizes resource behavior.

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
    ignore_changes        = [tags["LastUpdated"]]
    replace_triggered_by  = [terraform_data.version]
  }
}
```

Lifecycle arguments:

- `create_before_destroy`
- `prevent_destroy`
- `ignore_changes`
- `replace_triggered_by`

Precondition:

```hcl
lifecycle {
  precondition {
    condition     = var.instance_type != "t2.nano"
    error_message = "t2.nano is too small."
  }
}
```

Postcondition:

```hcl
lifecycle {
  postcondition {
    condition     = self.public_ip != ""
    error_message = "Instance did not receive a public IP."
  }
}
```

Action trigger:

```hcl
lifecycle {
  action_trigger {
    events  = [after_create, after_update]
    actions = [action.aws_lambda_invoke.restart_job]
  }
}
```

`action_trigger` requires action support in your Terraform and provider version.

## 7. Nested Blocks

Nested blocks appear inside top-level blocks.

### Provider-Specific Nested Blocks

Example:

```hcl
resource "aws_security_group" "web" {
  name = "web"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Provider documentation defines which nested blocks are valid.

### provisioner

Provisioners run commands after resource creation or before destruction.

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  provisioner "local-exec" {
    command = "echo ${self.id}"
  }
}
```

Remote exec:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx"
    ]
  }
}
```

Provisioner types:

- `local-exec`
- `remote-exec`
- `file`

Provisioners should be a last option. Prefer cloud-init, images, configuration management, Kubernetes, or provider-native resources when possible.

### connection

The `connection` block provides SSH or WinRM connection details for provisioners.

```hcl
connection {
  type        = "ssh"
  host        = self.public_ip
  user        = "ubuntu"
  private_key = file(var.private_key_path)
  timeout     = "5m"
}
```

### config

The `config` block is used by `action` blocks to pass provider-specific action configuration.

```hcl
action "example_type" "example" {
  config {
    name = "example"
  }
}
```

## 8. Functions

Terraform functions transform values.

### String Functions

```hcl
upper("dev")                    # "DEV"
lower("PROD")                   # "prod"
title("hello world")            # "Hello World"
trimspace(" hello ")            # "hello"
replace("hello", "l", "x")      # "hexxo"
split(",", "a,b,c")             # ["a", "b", "c"]
join("-", ["a", "b", "c"])      # "a-b-c"
startswith("prod-app", "prod")  # true
endswith("app.log", ".log")     # true
format("web-%02d", 3)           # "web-03"
substr("terraform", 0, 4)       # "terr"
```

### Collection Functions

```hcl
length(["a", "b"])
contains(["dev", "prod"], "prod")
lookup(var.tags, "Owner", "unknown")
keys(var.tags)
values(var.tags)
merge(local.default_tags, var.extra_tags)
concat(["a"], ["b"])
flatten([["a"], ["b"]])
distinct(["a", "a", "b"])
sort(["b", "a"])
slice(["a", "b", "c"], 0, 2)
zipmap(["a", "b"], [1, 2])
setunion(toset(["a"]), toset(["b"]))
setintersection(toset(["a", "b"]), toset(["b", "c"]))
```

### Numeric Functions

```hcl
abs(-5)
ceil(1.2)
floor(1.8)
max(1, 2, 3)
min(1, 2, 3)
pow(2, 3)
signum(-10)
```

### Encoding Functions

```hcl
jsonencode({ name = "web", port = 80 })
jsondecode("{\"name\":\"web\"}")
yamlencode({ name = "web" })
yamldecode(file("${path.module}/config.yaml"))
base64encode("hello")
base64decode("aGVsbG8=")
urlencode("hello world")
```

### File and Template Functions

```hcl
file("${path.module}/script.sh")
filebase64("${path.module}/image.png")
filemd5("${path.module}/script.sh")
filesha256("${path.module}/script.sh")
templatefile("${path.module}/user_data.sh.tftpl", {
  name = var.name
})
```

### Type Conversion Functions

```hcl
tostring(123)
tonumber("123")
tobool("true")
tolist(toset(["a", "b"]))
toset(["a", "b", "a"])
tomap({ a = "one" })
```

### Error Handling Functions

```hcl
try(var.config.name, "default-name")
can(regex("^prod", var.environment))
```

### Sensitive Value Functions

```hcl
sensitive(var.password)
nonsensitive(var.safe_value)
issensitive(var.password)
```

### IP Network Functions

```hcl
cidrsubnet("10.0.0.0/16", 8, 0)       # "10.0.0.0/24"
cidrsubnet("10.0.0.0/16", 8, 1)       # "10.0.1.0/24"
cidrhost("10.0.1.0/24", 10)           # "10.0.1.10"
cidrnetmask("10.0.1.0/24")            # "255.255.255.0"
cidrsubnets("10.0.0.0/16", 8, 8, 8)
```

### Date and Time Functions

```hcl
timestamp()
timeadd(timestamp(), "24h")
formatdate("YYYY-MM-DD", timestamp())
```

Be careful with `timestamp()`. It changes every run and can cause repeated diffs.

## 9. Variables and tfvars

### Variable Declaration

```hcl
variable "region" {
  description = "Cloud region."
  type        = string
  default     = "us-east-1"
}
```

### Variable Value Sources

Terraform can receive variable values from:

```bash
terraform apply -var="region=us-east-1"
terraform apply -var-file="prod.tfvars"
```

Environment variable:

```bash
export TF_VAR_region="us-east-1"
```

PowerShell:

```powershell
$env:TF_VAR_region = "us-east-1"
```

Auto-loaded files:

```text
terraform.tfvars
terraform.tfvars.json
*.auto.tfvars
*.auto.tfvars.json
```

### tfvars Syntax

```hcl
region = "us-east-1"
environment = "dev"

tags = {
  Project = "sonarqube"
  Owner   = "platform"
}

servers = {
  web = {
    instance_type = "t3.micro"
    subnet_id     = "subnet-123"
  }
}
```

### Variable Precedence

From lower to higher priority:

1. Environment variables: `TF_VAR_name`
2. `terraform.tfvars`
3. `terraform.tfvars.json`
4. `*.auto.tfvars` and `*.auto.tfvars.json`
5. `-var` and `-var-file` command line flags

## 10. State, Backend, and Workspaces

### Local Backend

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

### S3 Backend

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/app.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### HCP Terraform Cloud Block

```hcl
terraform {
  cloud {
    organization = "example-org"

    workspaces {
      name = "prod-app"
    }
  }
}
```

### Workspace Reference

```hcl
locals {
  is_prod = terraform.workspace == "prod"
}
```

CLI:

```bash
terraform workspace list
terraform workspace new dev
terraform workspace select dev
terraform workspace show
terraform workspace delete dev
```

## 11. Testing Syntax

Terraform test files use:

```text
*.tftest.hcl
*.tftest.json
```

Common location:

```text
tests/example.tftest.hcl
```

Basic test:

```hcl
variables {
  environment = "dev"
}

run "validate_name" {
  command = plan

  assert {
    condition     = var.environment == "dev"
    error_message = "Environment should be dev."
  }
}
```

Run:

```bash
terraform test
```

Test files can use:

- `test`
- `run`
- `variables`
- `provider`
- `assert`
- mocks and overrides when supported by the Terraform version

## 12. JSON Terraform Syntax

Normal HCL:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "example-bucket"
}
```

Equivalent JSON:

```json
{
  "resource": {
    "aws_s3_bucket": {
      "example": {
        "bucket": "example-bucket"
      }
    }
  }
}
```

JSON syntax is useful for generated Terraform. HCL is better for humans.

## 13. Common Patterns

### Standard Tags

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "${var.project}-${var.environment}-logs"
  tags   = local.common_tags
}
```

### Merge Default and Custom Tags

```hcl
tags = merge(local.common_tags, var.extra_tags)
```

### Create Only in Production

```hcl
count = var.environment == "prod" ? 1 : 0
```

### Stable for_each Keys

```hcl
resource "aws_instance" "servers" {
  for_each = var.servers

  ami           = var.ami_id
  instance_type = each.value.instance_type

  tags = {
    Name = each.key
  }
}
```

### Convert List to Map for for_each

```hcl
locals {
  servers_by_name = {
    for server in var.servers : server.name => server
  }
}
```

### Safe Optional Access

```hcl
locals {
  instance_type = try(var.server.instance_type, "t3.micro")
}
```

### Validate Input

```hcl
variable "install_mode" {
  type    = string
  default = "both"

  validation {
    condition     = contains(["ui", "cli", "both"], var.install_mode)
    error_message = "install_mode must be ui, cli, or both."
  }
}
```

### Render Shell Script

```hcl
resource "terraform_data" "bootstrap" {
  triggers_replace = {
    script_hash = filesha256("${path.module}/scripts/setup.sh")
  }

  provisioner "file" {
    content     = templatefile("${path.module}/scripts/setup.sh.tftpl", { port = var.port })
    destination = "/tmp/setup.sh"
  }
}
```

### terraform_data

`terraform_data` is a built-in resource useful for storing values in state or triggering provisioners without installing the old `null` provider.

```hcl
resource "terraform_data" "version" {
  input = var.revision
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    replace_triggered_by = [terraform_data.version]
  }
}
```

## 14. Complete Example

This example shows common Terraform syntax in one module.

### versions.tf

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### variables.tf

```hcl
variable "project" {
  type        = string
  description = "Project name."
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}

variable "servers" {
  type = map(object({
    instance_type = string
    subnet_id     = string
    enabled       = optional(bool, true)
  }))
}
```

### locals.tf

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  enabled_servers = {
    for name, server in var.servers : name => server
    if server.enabled
  }
}
```

### main.tf

```hcl
provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "server" {
  for_each = local.enabled_servers

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
  })

  lifecycle {
    precondition {
      condition     = each.value.instance_type != "t2.nano"
      error_message = "t2.nano is too small for this module."
    }
  }
}
```

### outputs.tf

```hcl
output "server_ids" {
  description = "Map of server IDs."
  value       = { for name, server in aws_instance.server : name => server.id }
}

output "server_private_ips" {
  description = "Map of server private IPs."
  value       = { for name, server in aws_instance.server : name => server.private_ip }
}
```

## 15. Quick Cheat Sheet

### Block Syntax

```hcl
terraform {}
provider "aws" {}
resource "aws_instance" "web" {}
data "aws_ami" "ubuntu" {}
ephemeral "random_password" "db" {}
action "aws_lambda_invoke" "job" {}
variable "name" {}
output "name" {}
locals {}
module "vpc" {}
import {}
moved {}
removed {}
check "name" {}
```

### Type Syntax

```hcl
string
number
bool
list(string)
set(string)
map(string)
object({ name = string, port = number })
tuple([string, number, bool])
any
optional(string)
optional(string, "default")
```

### Reference Syntax

```hcl
var.name
local.name
aws_instance.web.id
aws_instance.web[0].id
aws_instance.web["app"].id
data.aws_ami.ubuntu.id
module.vpc.vpc_id
ephemeral.random_password.db.result
action.aws_lambda_invoke.job
count.index
each.key
each.value
self.id
path.module
path.root
path.cwd
terraform.workspace
```

### Must-Know CLI

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
terraform output
terraform state list
terraform test
```

## 16. Official References

- Terraform Language Overview: https://developer.hashicorp.com/terraform/language
- HCL Syntax: https://developer.hashicorp.com/terraform/language/syntax/configuration
- Files and Structure: https://developer.hashicorp.com/terraform/language/files
- Type Constraints: https://developer.hashicorp.com/terraform/language/expressions/type-constraints
- Expressions: https://developer.hashicorp.com/terraform/language/expressions
- References: https://developer.hashicorp.com/terraform/language/expressions/references
- For Expressions: https://developer.hashicorp.com/terraform/language/expressions/for
- Meta-Arguments: https://developer.hashicorp.com/terraform/language/meta-arguments
- Resource Block: https://developer.hashicorp.com/terraform/language/block/resource
- Terraform Block: https://developer.hashicorp.com/terraform/language/block/terraform
- Ephemeral Block: https://developer.hashicorp.com/terraform/language/ephemeral
- Action Block: https://developer.hashicorp.com/terraform/language/block/action
- Import Blocks: https://developer.hashicorp.com/terraform/language/import
- Removed Block: https://developer.hashicorp.com/terraform/language/block/removed
- terraform_data Resource: https://developer.hashicorp.com/terraform/language/resources/terraform-data
- Write-Only Arguments: https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only
- Terraform Tests: https://developer.hashicorp.com/terraform/language/tests
- JSON Syntax: https://developer.hashicorp.com/terraform/language/syntax/json

