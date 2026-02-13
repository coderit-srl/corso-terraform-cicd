terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend: this config creates the S3 bucket used by the main backend,
  # so it can't store its own state there. Commit the state file to git.
}
