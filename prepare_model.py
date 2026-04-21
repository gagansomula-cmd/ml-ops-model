#!/usr/bin/env python3
"""
Prepare sklearn model for KServe deployment.
Converts JSON model config to sklearn pickle format and uploads to S3.

AWS Credentials:
  - Uses IAM roles automatically (no hardcoded AWS keys needed)
  - In GitHub Actions: Credentials provided by OIDC + GitHub Actions IAM role
  - In AWS: Uses IAM role credentials from EC2/EKS instance profile
  - Locally: Uses AWS CLI configured credentials or AWS_PROFILE environment variable
"""

import json
import joblib
import argparse
import sys
from pathlib import Path
import boto3

def prepare_sklearn_model(json_path: str, output_path: str = "model_artifacts/model.joblib"):
    """
    Convert JSON model config to sklearn-compatible pickle format.
    """
    print(f"Reading model config from: {json_path}")
    
    with open(json_path, 'r') as f:
        config = json.load(f)
    
    print(f"Model config: {config}")
    
    # For a linear regression model, we create a simple wrapper
    # that mimics sklearn's LinearRegression interface
    try:
        from sklearn.linear_model import LinearRegression
        import numpy as np
    except ImportError:
        print("ERROR: scikit-learn not installed. Install with: pip install scikit-learn")
        return False
    
    # Create a LinearRegression model and set its coefficients
    model = LinearRegression()
    
    # Set the learned parameters
    model.coef_ = np.array([config.get('weight', 0.0)])
    model.intercept_ = config.get('bias', 0.0)
    
    # Save the model
    joblib.dump(model, output_path)
    print(f"✅ Model saved to: {output_path}")
    
    return True

def upload_to_s3(local_path: str, s3_bucket: str, s3_key: str, region: str = "us-east-1"):
    """
    Upload model to S3 bucket using IAM role credentials.
    
    Credentials are automatically obtained from:
    - GitHub Actions OIDC + IAM role (in CI/CD)
    - Instance profile (in AWS EC2/EKS)
    - AWS CLI configuration (locally)
    
    No hardcoded AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed.
    """
    try:
        # boto3 automatically uses IAM role credentials
        # No explicit credentials parameter needed
        s3_client = boto3.client('s3', region_name=region)
        
        # First verify bucket exists and is accessible
        try:
            s3_client.head_bucket(Bucket=s3_bucket)
            print(f"✅ S3 bucket '{s3_bucket}' is accessible")
        except s3_client.exceptions.NoSuchBucket:
            print(f"❌ S3 bucket '{s3_bucket}' does not exist")
            print(f"   Bucket should be created by Terraform: terraform apply")
            return False
        except Exception as e:
            print(f"⚠️  Cannot access bucket '{s3_bucket}': {e}")
            print("")
            print("Possible issues with IAM role permissions:")
            print("1. GitHub Actions IAM role lacks S3 permissions:")
            print("   - Check terraform/github-oidc.tf has s3-models-access policy attached")
            print("")
            print("2. Running locally? Ensure AWS credentials are configured:")
            print("   - aws configure")
            print("   - Or set AWS_PROFILE environment variable")
            print("")
            print("3. In EKS? Check node role has S3 permissions:")
            print("   - terraform/s3-models.tf should attach eks-s3-models-access policy")
            return False
        
        print(f"Uploading {local_path} to s3://{s3_bucket}/{s3_key}")
        s3_client.upload_file(local_path, s3_bucket, s3_key)
        print(f"✅ Model uploaded to: s3://{s3_bucket}/{s3_key}")
        
        return True
    except Exception as e:
        print(f"❌ Failed to upload to S3: {e}")
        print("")
        print("Troubleshooting IAM role permissions:")
        print("1. Verify IAM role has S3 access policy:")
        print("   - GitHub Actions: Check aws_iam_role_policy 'github-actions-s3-models-access'")
        print("   - EKS pods: Check aws_iam_role_policy 'eks-s3-models-access'")
        print("")
        print("2. Re-apply Terraform to add missing permissions:")
        print("   cd terraform && terraform apply")
        print("")
        print("3. Or upload manually using AWS CLI (requires local AWS credentials):")
        print(f"   aws s3 cp {local_path} s3://{s3_bucket}/{s3_key}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Prepare sklearn model for KServe deployment")
    parser.add_argument(
        "--json-path",
        default="model_artifacts/linear_regression_model.json",
        help="Path to JSON model config"
    )
    parser.add_argument(
        "--output",
        default="model_artifacts/model.joblib",
        help="Output path for sklearn model pickle"
    )
    parser.add_argument(
        "--upload-s3",
        action="store_true",
        help="Upload model to S3"
    )
    parser.add_argument(
        "--s3-bucket",
        default="mlops-trainig-679631209574-us-east-1-an",
        help="S3 bucket name"
    )
    parser.add_argument(
        "--s3-key",
        default="linear-regression/model.joblib",
        help="S3 object key"
    )
    parser.add_argument(
        "--region",
        default="us-east-1",
        help="AWS region"
    )
    
    args = parser.parse_args()
    
    print("="*60)
    print("Model Preparation with IAM Role-based S3 Access")
    print("="*60)
    print("")
    print("AWS Credentials:")
    print("  - GitHub Actions: OIDC + GitHubActionsRole (no hardcoded keys)")
    print("  - AWS/EKS: Instance profile / node role (no hardcoded keys)")
    print("  - Locally: AWS CLI configuration (aws configure)")
    print("")
    
    # Prepare the model
    if not prepare_sklearn_model(args.json_path, args.output):
        return 1
    
    # Upload to S3 if requested
    if args.upload_s3:
        if not upload_to_s3(args.output, args.s3_bucket, args.s3_key, args.region):
            return 1
    
    print("\n" + "="*60)
    print("✅ Model preparation complete!")
    print("="*60)
    
    if args.upload_s3:
        print(f"\nModel is available at:")
        print(f"  s3://{args.s3_bucket}/{args.s3_key}")
    else:
        print(f"\nModel saved locally at:")
        print(f"  {args.output}")
        print(f"\nTo upload to S3, run:")
        print(f"  python prepare_model.py --json-path {args.json_path} --upload-s3")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
