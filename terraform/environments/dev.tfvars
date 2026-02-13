environment          = "dev"
project_name         = "multi-env-demo"
aws_region           = "us-east-1"
s3_bucket_name       = "multi-env-demo-dev-bucket"
lambda_function_name = "multi-env-demo-dev"
lambda_handler       = "index.handler"
lambda_runtime       = "python3.11"

tags = {
  Environment = "dev"
  Project     = "multi-env-demo"
  ManagedBy   = "Terraform"
}
