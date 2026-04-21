# Reference to existing ML Models S3 bucket
# This bucket is used by KServe to download models for inference serving

locals {
  ml_models_bucket = "mlops-trainig-679631209574-us-east-1-an"
}

# Get information about the existing bucket
data "aws_s3_bucket" "ml_models" {
  bucket = local.ml_models_bucket
}

# ===== IAM Policy for EKS Node Role (Kubernetes Pods) =====
# This allows KServe inference pods to download models from S3
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
  
  # Allow uploading models from training/CI/CD
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

# Create inline policy for EKS node role to access models
# This policy is attached to the node IAM role
resource "aws_iam_role_policy" "eks_s3_access" {
  name   = "eks-s3-models-access"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.eks_s3_access.json
}

# ===== IAM Policy for GitHub Actions Role =====
# This allows GitHub Actions to upload models to S3 using IAM role
data "aws_iam_policy_document" "github_actions_s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucketVersions"
    ]
    resources = [
      data.aws_s3_bucket.ml_models.arn,
      "${data.aws_s3_bucket.ml_models.arn}/*"
    ]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject"
    ]
    resources = [
      "${data.aws_s3_bucket.ml_models.arn}/linear-regression/*",
      "${data.aws_s3_bucket.ml_models.arn}/models/*",
      "${data.aws_s3_bucket.ml_models.arn}/training-outputs/*"
    ]
  }
}

# Attach S3 policy to GitHub Actions role
resource "aws_iam_role_policy" "github_actions_s3_access" {
  name   = "github-actions-s3-models-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3_access.json

  depends_on = [aws_iam_role.github_actions]
}

# ===== Outputs =====
output "ml_models_bucket" {
  description = "S3 bucket for ML models (IAM role-based access)"
  value       = local.ml_models_bucket
}

output "ml_models_bucket_arn" {
  description = "ARN of ML models bucket"
  value       = data.aws_s3_bucket.ml_models.arn
}

output "s3_access_info" {
  description = "S3 access configuration - uses IAM roles only (no hardcoded credentials)"
  value = {
    bucket_name         = local.ml_models_bucket
    bucket_arn          = data.aws_s3_bucket.ml_models.arn
    eks_node_policy     = "eks-s3-models-access"
    github_actions_policy = "github-actions-s3-models-access"
    authentication      = "IAM Roles (GitHub OIDC + EKS node roles)"
    credential_method   = "Temporary STS tokens - no long-lived keys"
  }
}
