# Terraform Multi-Environment CICD Project Plan

## Overview
A multi-environment Terraform project (dev/staging/prod) with GitHub Actions workflows demonstrating:
- Infrastructure as Code (S3 + Lambda per environment)
- S3 remote state backend with DynamoDB locking
- Terraform workspaces + .tfvars for environment separation
- GitHub Actions workflows with approval gates
- Plan/Apply separation for safety

## Architecture

### AWS Resources
- **Per environment**: S3 bucket + Lambda function with environment-specific tags and configurations
- **Shared**: S3 bucket for Terraform state + DynamoDB table for state locking

### Infrastructure Layout
```
├── src/
│   └── lambda/
│       └── index.py                # Lambda function code
├── terraform/
│   ├── main.tf                     # Main configuration (S3 + Lambda + archive_file)
│   ├── variables.tf                # Variable definitions
│   ├── outputs.tf                  # Outputs
│   ├── backend.tf                  # S3 backend + state lock config
│   ├── provider.tf                 # AWS provider configuration
│   └── environments/
│       ├── dev.tfvars              # Dev environment variables
│       ├── staging.tfvars          # Staging environment variables
│       └── prod.tfvars             # Prod environment variables
├── .github/workflows/
│   ├── terraform-plan.yml          # Runs on PR: plan for all envs
│   ├── terraform-apply-dev.yml     # Manual trigger: apply to dev
│   ├── terraform-apply-staging.yml # Manual trigger + approval: apply to staging
│   └── terraform-apply-prod.yml    # Manual trigger + approval: apply to prod
├── .gitignore                      # Terraform ignores
└── README.md                       # Setup instructions
```

## Implementation Steps

1. **Initialize git repo** and GitHub Actions secrets setup
2. **Create Terraform backend infrastructure** (S3 + DynamoDB) - one-time setup
3. **Write Terraform configuration** for S3 buckets and Lambda functions
4. **Create GitHub Actions workflows**:
   - terraform-plan.yml: Runs on PRs, plans for all environments
   - terraform-apply-dev.yml: Auto-applies to dev on PR merge
   - terraform-apply-staging.yml: Requires manual approval from staging environment
   - terraform-apply-prod.yml: Requires manual approval from production environment
5. **Add documentation** with setup instructions and usage guide
6. **Seed initial state** (bootstrap the S3 backend manually)

## Key Features

- **Workspaces**: Each environment (dev/staging/prod) uses Terraform workspace for isolation
- **Approval Gates**: Staging and Prod deployments require GitHub approval
- **Plan Commenting**: Terraform plan output posted to PR comments
- **Secret Management**: AWS credentials via GitHub Actions secrets
- **Free Tier Only**: All resources fit within AWS free tier limits
- **Idempotent**: Safe to run multiple times, no drift

## AWS Free Tier Considerations

- S3: 5 GB free storage (3 buckets = ~1-2 GB total)
- Lambda: 1M requests/month free (demo workload well under this)
- DynamoDB: 25 GB free storage + read/write capacity units (state locking minimal usage)
- All resources use minimal configuration to stay within free tier

## Deliverables

- Complete Terraform module for multi-environment deployment
- 4 GitHub Actions workflows with appropriate approval gates
- README with setup instructions
- Example .gitignore and backend configuration
