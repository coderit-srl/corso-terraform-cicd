# Multi-Environment Terraform CICD Demo

A complete example of deploying infrastructure across three environments (dev, staging, prod) using Terraform and GitHub Actions with approval workflows.

## Project Overview

This project demonstrates:
- **Infrastructure as Code**: Define AWS resources (S3 + Lambda) using Terraform
- **Multi-Environment Setup**: Separate configuration per environment using workspaces and tfvars
- **GitHub Actions CICD**: Automated plan and apply workflows
- **Approval Gates**: Staging and production deployments require manual approval
- **State Management**: Remote state stored in S3 with DynamoDB locking
- **AWS Free Tier**: All resources fit within free tier limits

## Architecture

### Environments

- **dev**: Automatic deployment on push to main branch
- **staging**: Manual trigger with approval required
- **prod**: Manual trigger with approval required

### AWS Resources per Environment

- **S3 Bucket**: Versioned, with public access blocked
- **Lambda Function**: Simple Python function with CloudWatch logging
- **IAM Role**: Lambda execution role with basic permissions

### Shared Infrastructure (One-Time Setup)

- **S3 Bucket**: Terraform state storage
- **DynamoDB Table**: State locking

## Prerequisites

1. **AWS Account**: Free tier eligible
2. **GitHub Account**: With repository access
3. **Terraform**: Installed locally (v1.6.0+)
4. **AWS CLI**: Installed locally (optional, for bootstrapping)

## Setup Instructions

### 1. Bootstrap AWS Backend (One-Time Only)

First, create the S3 bucket and DynamoDB table for Terraform state. This must be done manually before the automation can work.

```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for state
aws s3 mb s3://terraform-state-demo-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-demo-bucket \
  --versioning-configuration Status=Enabled \
  --region us-east-1

# Block public access
aws s3api put-public-access-block \
  --bucket terraform-state-demo-bucket \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region us-east-1
```

### 2. Set Up AWS Credentials for GitHub Actions

Create an IAM role for GitHub Actions to assume:

```bash
# Create trust policy JSON
cat > /tmp/trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Replace ACCOUNT_ID and YOUR_GITHUB_ORG/YOUR_REPO in the JSON

# Create IAM role for OIDC
aws iam create-role \
  --role-name github-actions-terraform-role \
  --assume-role-policy-document file:///tmp/trust-policy.json

# Attach policy for Terraform operations
aws iam put-role-policy \
  --role-name github-actions-terraform-role \
  --policy-name terraform-permissions \
  --policy-document '$(cat policy.json)'
```

Create a `policy.json` file with necessary permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "lambda:*",
        "iam:*",
        "logs:*",
        "dynamodb:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-demo-bucket",
        "arn:aws:s3:::terraform-state-demo-bucket/*",
        "arn:aws:dynamodb:us-east-1:ACCOUNT_ID:table/terraform-state-lock"
      ]
    }
  ]
}
```

### 3. Add GitHub Secrets

In your GitHub repository settings, add the following secret:

- `AWS_ROLE_ARN`: ARN of the GitHub Actions role created above

```
arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-role
```

### 4. Configure GitHub Environments (Optional but Recommended)

Set up environment protection rules:

1. Go to **Settings** → **Environments** → **New environment**
2. Create environments: `dev`, `staging`, `production`
3. For `staging` and `production`, add required reviewers
4. Add deployment branches (restrict to `main` branch)

### 5. Test the Setup

1. Create a test branch and make a small change to terraform files
2. Open a Pull Request to main
3. GitHub Actions will automatically run `terraform plan` for all environments
4. Push to main to trigger dev deployment
5. Manually trigger staging and prod deployment workflows

## Project Structure

```
.
├── src/
│   └── lambda/
│       └── index.py                 # Lambda function source code
├── terraform/
│   ├── main.tf                      # S3, Lambda, IAM resources + archive_file
│   ├── variables.tf                 # Variable definitions
│   ├── outputs.tf                   # Output definitions
│   ├── backend.tf                   # Terraform settings + S3 backend
│   ├── provider.tf                  # AWS provider configuration
│   └── environments/
│       ├── dev.tfvars               # Dev environment variables
│       ├── staging.tfvars           # Staging environment variables
│       └── prod.tfvars              # Prod environment variables
├── .github/workflows/
│   ├── terraform-plan.yml           # Plan on PR (all environments)
│   ├── terraform-apply-dev.yml      # Auto-apply to dev
│   ├── terraform-apply-staging.yml  # Manual + approval for staging
│   └── terraform-apply-prod.yml     # Manual + approval for prod
├── .gitignore                       # Git ignore rules
├── PLAN.md                          # Implementation plan
└── README.md                        # This file
```

## Workflow Descriptions

### terraform-plan.yml

**Trigger**: Pull requests that modify terraform files

**What it does**:
1. Runs `terraform plan` for all three environments
2. Validates Terraform configuration
3. Checks formatting
4. Posts results as PR comments

### terraform-apply-dev.yml

**Trigger**: Push to main branch OR manual workflow dispatch

**What it does**:
1. Runs `terraform plan` for dev
2. Automatically applies changes (no approval required)
3. Exports outputs as artifact

### terraform-apply-staging.yml

**Trigger**: Manual workflow dispatch

**What it does**:
1. Runs `terraform plan` for staging
2. Waits for manual approval (via GitHub environment)
3. Applies changes upon approval
4. Exports outputs as artifact

### terraform-apply-prod.yml

**Trigger**: Manual workflow dispatch (most restricted)

**What it does**:
1. Runs `terraform plan` for production
2. Waits for manual approval (via GitHub environment)
3. Applies changes upon approval
4. Exports outputs as artifact

## Local Development

To test changes locally before pushing:

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan changes for dev
terraform plan -var-file="environments/dev.tfvars"

# Plan changes for staging
terraform plan -var-file="environments/staging.tfvars"

# Plan changes for prod
terraform plan -var-file="environments/prod.tfvars"

# Apply changes (only for dev)
terraform apply -var-file="environments/dev.tfvars"
```

## Important Notes

### State Management

- Terraform state is stored in S3 with encryption enabled
- DynamoDB table provides state locking to prevent concurrent modifications
- **DO NOT** commit `.tfstate` files to Git
- **DO NOT** manually modify state files

### Environment Variables in tfvars

The `.tfvars` files are committed to the repository (they contain no secrets). They define:
- Environment name
- S3 bucket names
- Lambda function names
- Resource tags

Actual AWS credentials come from GitHub Actions via OIDC, not from secrets.

### Free Tier Considerations

All resources are configured to stay within AWS free tier:
- S3: 5 GB free storage (3 buckets ~1-2 GB total)
- Lambda: 1M requests/month free
- DynamoDB: 25 GB free, minimal read/write capacity
- CloudWatch Logs: 5 GB free ingestion

### Cost Monitoring

Monitor your AWS usage in the console:
1. AWS Console → Billing → Cost and Usage Reports
2. Filter by service and tag
3. Set up billing alerts for unexpected charges

## Troubleshooting

### Issue: "terraform init" fails with backend errors

**Solution**: Ensure the S3 bucket and DynamoDB table exist and are properly configured.

### Issue: Lambda code changes not detected by Terraform

**Solution**: The `archive_file` data source in `main.tf` automatically zips `src/lambda/index.py` at plan time and tracks content changes via `source_code_hash`. Ensure the source file exists at `src/lambda/index.py`.

### Issue: AWS credentials error in GitHub Actions

**Solution**:
- Verify the IAM role exists and has correct trust policy
- Check that the `AWS_ROLE_ARN` secret is set correctly
- Verify OIDC provider exists in AWS account

### Issue: "Access Denied" errors when applying Terraform

**Solution**: Ensure the GitHub Actions IAM role has policies for:
- S3 (state and app bucket)
- Lambda (function and layers)
- IAM (roles and policies)
- CloudWatch (logs)

## Next Steps

1. Add more AWS resources (RDS, API Gateway, etc.)
2. Implement automated testing (Terratest, tfsec)
3. Add Terraform state locking visualization
4. Implement drift detection
5. Add cost estimation in PR comments (Infracost)
6. Create runbooks for common operations

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub Actions for Terraform](https://github.com/hashicorp/setup-terraform)
- [AWS Free Tier](https://aws.amazon.com/free)
- [OIDC in GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## License

MIT
