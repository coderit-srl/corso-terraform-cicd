terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-101539044592"
    key          = "terraform.tfstate"
    region       = "eu-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
