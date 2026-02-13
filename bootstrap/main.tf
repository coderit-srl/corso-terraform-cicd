provider "aws" {
  region = var.aws_region
}

# --- S3 bucket for Terraform remote state ---

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- GitHub Actions OIDC ---

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# --- IAM role for GitHub Actions ---

resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-permissions"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Sid    = "AppBuckets"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "arn:aws:s3:::multi-env-demo-*-bucket",
          "arn:aws:s3:::multi-env-demo-*-bucket/*"
        ]
      },
      {
        Sid    = "LambdaFunctions"
        Effect = "Allow"
        Action = ["lambda:*"]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:multi-env-demo-*"
      },
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/multi-env-demo-*"
      },
      {
        Sid    = "CloudWatchLogsDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsManage"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/multi-env-demo-*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/multi-env-demo-*:*"
        ]
      }
    ]
  })
}
