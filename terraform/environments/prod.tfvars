environment          = "prod"
project_name         = "multi-env-demo"
aws_region           = "eu-south-1"
s3_bucket_name       = "multi-env-demo-prod-bucket"
lambda_function_name = "multi-env-demo-prod"
lambda_handler       = "index.handler"
lambda_runtime       = "python3.11"

tags = {
  Environment = "prod"
  Project     = "multi-env-demo"
  ManagedBy   = "Terraform"
}
