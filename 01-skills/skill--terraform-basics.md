# Skill: Terraform Infrastructure as Code

## Overview
Terraform declares infrastructure as versioned, reviewable code. The critical workflow is plan-before-apply: `terraform plan` shows exactly what will change before anything touches real infrastructure. State must live in a shared backend (S3 + DynamoDB) — local state files cause team conflicts and can't be recovered if lost.

## Implementation

### Project Structure
```
infra/
├── main.tf          # provider config + backend
├── variables.tf     # input variable declarations
├── outputs.tf       # cross-module references
├── terraform.tfvars # actual values (NOT committed — add to .gitignore)
├── modules/
│   ├── database/
│   └── networking/
└── environments/
    ├── staging/
    └── production/
```

### Backend (S3 + DynamoDB Lock)
```hcl
# main.tf
terraform {
  required_version = ">= 1.5"
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "myapp-terraform-locks"  # prevents concurrent applies
  }
}
```

### Workspaces per Environment
```bash
terraform workspace new staging
terraform workspace new production
terraform workspace select staging
terraform apply -var-file="environments/staging.tfvars"
```
Use workspaces when infrastructure is identical between environments but values differ (instance sizes, replica counts). Use separate state files when environments diverge significantly.

### Module Pattern
```hcl
# modules/database/main.tf
variable "instance_class" { type = string }
variable "name"           { type = string }

resource "aws_db_instance" "this" {
  identifier     = var.name
  instance_class = var.instance_class
  # ...
}

output "endpoint" { value = aws_db_instance.this.endpoint }

# root main.tf — consuming the module
module "db_production" {
  source         = "./modules/database"
  name           = "myapp-prod"
  instance_class = "db.t3.medium"
}

# reference the output
resource "aws_ssm_parameter" "db_url" {
  value = module.db_production.endpoint
}
```

### Standard Workflow
```bash
terraform init          # download providers, configure backend
terraform fmt -check    # fail CI if formatting is wrong
terraform validate      # check syntax and type errors
terraform plan -out=tfplan   # save plan artifact
# Human reviews tfplan output
terraform apply tfplan  # apply exactly what was planned
```

### Variables and Secrets
```hcl
# variables.tf
variable "db_password" {
  type      = string
  sensitive = true   # suppresses value from logs
}
```
```bash
# Pass secrets via env vars (never in .tf files or .tfvars committed to git)
export TF_VAR_db_password="$(aws secretsmanager get-secret-value ...)"
```

## Key Rules
- Never commit `terraform.tfvars` or any file containing real secrets — use environment variables or a secrets manager
- Always run `terraform plan` and review the diff before `terraform apply` — especially check for `forces replacement` which destroys and recreates resources
- Store state in S3 with DynamoDB locking — never local state in a team environment
- Use one workspace per environment; name the state key to include the environment (`production/terraform.tfstate`)
- Mark sensitive outputs and variables with `sensitive = true` to prevent them appearing in logs
- Pin provider versions with `~> 5.0` to prevent surprise breaking changes during `terraform init`
- Run `terraform fmt -check` and `terraform validate` in CI before plan
