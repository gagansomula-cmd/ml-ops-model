# S3 bucket for Terraform state (commented out if already created)
# If bucket already exists, run: terraform import aws_s3_bucket.terraform_state ml-ops-terraform-state-ACCOUNT_ID
resource "aws_s3_bucket" "terraform_state" {
  count  = 0 # Set to 0 if S3 bucket already exists, 1 to create
  bucket = "ml-ops-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "ml-ops-terraform-state"
    }
  )
}

# Enable versioning on state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = 0 # Set to 1 if creating S3 bucket
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption on state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = 0 # Set to 1 if creating S3 bucket
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = 0 # Set to 1 if creating S3 bucket
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform locks
resource "aws_dynamodb_table" "terraform_locks" {
  count        = 0 # Set to 1 if creating DynamoDB table
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "terraform-locks"
    }
  )
}

output "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  value       = try(aws_s3_bucket.terraform_state[0].id, "ml-ops-terraform-state-${data.aws_caller_identity.current.account_id}")
}

output "terraform_locks_table" {
  description = "Name of the DynamoDB table for Terraform locks"
  value       = try(aws_dynamodb_table.terraform_locks[0].name, "terraform-locks")
}
