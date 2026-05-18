# Principle: Infrastructure as Code

## Overview
Every infrastructure resource created through a cloud console is invisible to version control, unreviewable by teammates, and unrepeatable on a new environment. Infrastructure as Code (IaC) treats servers, databases, DNS records, IAM roles, and network configuration the same way application code is treated: defined in files, reviewed in PRs, applied through automation, and recoverable from git history.

## Why Manual Console Changes Fail at Scale

- **Invisible:** No one knows who created the resource, when, or why
- **Unrepeatable:** "Just create a VPC like the one in prod" requires tribal knowledge
- **Undocumented:** Console clicks leave no audit trail beyond cloud provider logs
- **Unrollbackable:** You cannot `git revert` a console change
- **Drift:** Dev, staging, and prod silently diverge over months of manual tweaks

## Core Capabilities IaC Enables

### Clone environments
```hcl
# Terraform — create staging identical to prod by changing one variable
module "app" {
  source      = "./modules/app"
  environment = var.environment  # "staging" vs "production"
  db_size     = var.environment == "production" ? "db-4vcpu-8gb" : "db-1vcpu-1gb"
}
```

### Code review for infra changes
Infra changes go through the same PR process as application code. A database security group opening port 5432 to 0.0.0.0/0 is caught in review before it reaches production.

### Rollback via git revert
```bash
git revert abc1234  # reverts the Terraform change that opened the bad security rule
terraform apply     # restores the previous state
```

### Drift detection
```bash
terraform plan  # shows delta between desired state (code) and actual state (cloud)
# If this shows changes you didn't make, someone modified the console manually
```

## Tooling Options

| Tool | Best for | Language |
|---|---|---|
| Terraform/OpenTofu | Multi-cloud, mature ecosystem | HCL |
| Pulumi | Prefer TypeScript/Python | TS, Python, Go |
| AWS CDK | AWS-only, app-centric teams | TS, Python |
| Bicep | Azure-only | Domain-specific |

## Common IaC Resources

```hcl
# Vercel project + env vars
resource "vercel_project" "app" {
  name      = "my-app"
  framework = "nextjs"
}

resource "vercel_project_environment_variable" "api_key" {
  project_id = vercel_project.app.id
  key        = "API_KEY"
  value      = var.api_key
  target     = ["production", "preview"]
}
```

## State Management

Terraform tracks real-world resources in a state file. This file:
- Must be stored remotely (S3, Terraform Cloud, GCS) — never committed to git
- Must be locked during apply operations to prevent concurrent modifications
- Contains secrets — enable encryption at rest

```hcl
terraform {
  backend "s3" {
    bucket         = "my-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Adoption Strategy for Existing Infra

Don't rewrite everything — import existing resources:
```bash
terraform import aws_s3_bucket.assets my-existing-bucket-name
```
This brings existing resources under IaC management without recreating them.

## Key Rules
- All new infrastructure goes in code first; never in the console
- State files must be remote and encrypted; never in git
- `terraform plan` is a required review step before `terraform apply`
- Console-only changes are a policy violation — not just a best practice
- Treat IaC PRs with the same scrutiny as application code PRs; they affect production
- Use modules to avoid copy-pasting config between environments
