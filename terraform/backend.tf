# S3 backend for Terraform state
# Create S3 bucket first: aws s3api create-bucket --bucket ml-ops-terraform-state-679631209574 --region us-east-1
# Then run: terraform init -reconfigure

terraform {
  backend "s3" {
    bucket       = "ml-ops-terraform-state-679631209574"
    key          = "ml-ops/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
