# S3 backend for Terraform state (configure after creating S3 bucket)
# Uncomment and update bucket name after running: terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks
/*
terraform {
  backend "s3" {
    bucket         = "ml-ops-terraform-state-ACCOUNT_ID"
    key            = "ml-ops/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
*/
