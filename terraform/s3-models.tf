# Reference to existing ML Models S3 bucket
# This bucket is used by KServe to download models for inference serving

locals {
  ml_models_bucket = "mlops-trainig-679631209574-us-east-1-an"
}

# Get information about the existing bucket
data "aws_s3_bucket" "ml_models" {
  bucket = local.ml_models_bucket
}

# IAM policy for EKS pods to access models in S3
data "aws_iam_policy_document" "eks_s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:ListBucketVersions"
    ]
    resources = [
      data.aws_s3_bucket.ml_models.arn,
      "${data.aws_s3_bucket.ml_models.arn}/*"
    ]
  }
  
  # Also allow PutObject for uploading new models from CI/CD
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      "${data.aws_s3_bucket.ml_models.arn}/linear-regression/*",
      "${data.aws_s3_bucket.ml_models.arn}/models/*",
      "${data.aws_s3_bucket.ml_models.arn}/training-outputs/*"
    ]
  }
}

# Create inline policy for node role to access models
resource "aws_iam_role_policy" "eks_s3_access" {
  name   = "eks-s3-models-access"
  role   = aws_iam_role.eks_node_role.id
  policy = data.aws_iam_policy_document.eks_s3_access.json
}

# Output bucket name for reference
output "ml_models_bucket" {
  description = "S3 bucket for ML models"
  value       = local.ml_models_bucket
}

output "ml_models_bucket_arn" {
  description = "ARN of ML models bucket"
  value       = data.aws_s3_bucket.ml_models.arn
}
