# S3 Setup Guide for MLflow Models

This guide explains how to configure automatic S3 uploads for trained models.

## 🎯 Overview

When enabled, the training script will automatically:
1. Train models locally
2. Log them to MLflow
3. Push the model artifacts to AWS S3
4. Store the S3 location in MLflow for tracking

## 📋 Prerequisites

- AWS account with S3 access
- AWS credentials configured
- Python packages installed: `boto3`

## 🔧 Setup Steps

### Step 1: Create S3 Bucket

```powershell
# Using AWS CLI (Python module)
python -m awscli s3 mb s3://your-ml-models-bucket --region us-east-1

# Or use AWS Console
# S3 → Create bucket → Enter name → Create
```

### Step 2: Configure AWS Credentials

Choose one of these methods:

#### Method 1: AWS CLI Configuration (Easiest)

```powershell
# Configure AWS credentials interactively
python -m awscli configure

# You'll be prompted for:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: [us-east-1]
# Default output format: [json]
```

#### Method 2: Environment Variables

```powershell
# Set in PowerShell
$env:AWS_ACCESS_KEY_ID = "your-access-key-id"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
$env:AWS_DEFAULT_REGION = "us-east-1"

# Or in Command Prompt
set AWS_ACCESS_KEY_ID=your-access-key-id
set AWS_SECRET_ACCESS_KEY=your-secret-access-key
set AWS_DEFAULT_REGION=us-east-1
```

#### Method 3: .env File

Create `mlflow/.env`:

```
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_DEFAULT_REGION=us-east-1
MLFLOW_S3_BUCKET=your-ml-models-bucket
MLFLOW_S3_PREFIX=models
```

Load with:
```powershell
# In PowerShell, before running training
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}
```

### Step 3: Set MLflow S3 Environment Variables

```powershell
# Configure the S3 bucket for models
$env:MLFLOW_S3_BUCKET = "your-ml-models-bucket"
$env:MLFLOW_S3_PREFIX = "models"  # Optional: prefix for S3 keys
```

### Step 4: Install boto3 (if not already installed)

```powershell
# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install boto3 (already in requirements.txt)
pip install -r requirements.txt
```

## 🚀 Usage

### Run Training with S3 Upload

```powershell
# Set environment variables
$env:AWS_ACCESS_KEY_ID = "your-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret"
$env:MLFLOW_S3_BUCKET = "your-bucket-name"

# Run training
python train_with_mlflow.py
```

### Output Example

```
📦 S3 Configuration:
   Bucket: your-ml-models-bucket
   Prefix: models

🔬 EXPERIMENT 1: Baseline Model
...
🔐 Logging model...

📤 Pushing model to S3...
  ✓ models/linear-regression-baseline/fde626b5dc444e9fac2e0aa582f3fb44/model.pkl
  ✓ models/linear-regression-baseline/fde626b5dc444e9fac2e0aa582f3fb44/MLmodel
  ✓ models/linear-regression-baseline/fde626b5dc444e9fac2e0aa582f3fb44/conda.yaml
✅ Model pushed to: s3://your-ml-models-bucket/models/linear-regression-baseline/fde626b5dc444e9fac2e0aa582f3fb44

✅ Run completed successfully!
```

## 📁 S3 Bucket Structure

After training, your S3 bucket will look like:

```
s3://your-bucket/
├── models/
│   └── linear-regression-baseline/
│       ├── fde626b5dc444e9fac2e0aa582f3fb44/  # Run ID 1
│       │   ├── model.pkl
│       │   ├── MLmodel
│       │   └── conda.yaml
│       └── ca90269fa217461e8b1ba8ed9ecf1f94/  # Run ID 2
│           ├── model.pkl
│           ├── MLmodel
│           └── conda.yaml
```

## 🔍 Verify Upload

### List files in S3

```powershell
# Using AWS CLI
python -m awscli s3 ls s3://your-ml-models-bucket/ --recursive

# Output:
# 2024-04-20 10:30:15       1234 models/linear-regression-baseline/fde626.../model.pkl
# 2024-04-20 10:30:16        567 models/linear-regression-baseline/fde626.../MLmodel
```

### Download a model from S3

```powershell
# Download model
python -m awscli s3 cp s3://your-bucket/models/linear-regression-baseline/fde626b5dc444e9fac2e0aa582f3fb44/model.pkl ./downloaded_model.pkl

# Use in Python
import pickle
with open('downloaded_model.pkl', 'rb') as f:
    model = pickle.load(f)
```

## 📊 MLflow Integration

Models are tracked in MLflow with S3 location:

```
MLflow UI → Experiment → Run Details:
- Parameters: s3_location = "s3://bucket/models/..."
- Artifacts: Listed in Artifacts tab
- Model: Logged as sklearn model
```

## 🔐 Security Best Practices

### 1. Use IAM Roles (Production)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-ml-models-bucket",
        "arn:aws:s3:::your-ml-models-bucket/*"
      ]
    }
  ]
}
```

### 2. Never Commit Credentials

Add to `.gitignore`:
```
.env
aws_credentials
```

### 3. Use Environment Variables

Always use environment variables, never hardcode credentials:

```python
# ❌ BAD
import boto3
s3 = boto3.client('s3', 
    aws_access_key_id='AKIAIOSFODNN7EXAMPLE',
    aws_secret_access_key='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
)

# ✅ GOOD
import boto3
import os
s3 = boto3.client('s3')  # Uses environment variables automatically
```

## ❌ Troubleshooting

### Error: "No credentials found"

**Cause:** AWS credentials not configured

**Solution:**
```powershell
# Check credentials
python -m awscli configure list

# If not configured:
python -m awscli configure

# Or set environment variables:
$env:AWS_ACCESS_KEY_ID = "your-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret"
```

### Error: "Access Denied" or "403 Forbidden"

**Cause:** IAM user doesn't have S3 permissions

**Solution:**
1. Check IAM user permissions
2. Add S3 permissions:
   ```json
   "Action": ["s3:PutObject", "s3:ListBucket"]
   ```
3. Verify bucket name is correct

### Error: "NoSuchBucket"

**Cause:** S3 bucket doesn't exist or wrong name

**Solution:**
```powershell
# List your buckets
python -m awscli s3 ls

# Create bucket if needed
python -m awscli s3 mb s3://your-bucket-name

# Update MLFLOW_S3_BUCKET environment variable
$env:MLFLOW_S3_BUCKET = "correct-bucket-name"
```

### Models not uploading (S3 disabled)

**Cause:** MLFLOW_S3_BUCKET environment variable not set

**Solution:**
```powershell
# Set the bucket
$env:MLFLOW_S3_BUCKET = "your-bucket"

# Verify it's set
$env:MLFLOW_S3_BUCKET

# Re-run training
python train_with_mlflow.py
```

## 📚 Complete Example Script

Save as `run_training_with_s3.ps1`:

```powershell
# Configure AWS credentials
$env:AWS_ACCESS_KEY_ID = "your-access-key-id"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
$env:AWS_DEFAULT_REGION = "us-east-1"

# Configure MLflow S3
$env:MLFLOW_S3_BUCKET = "your-ml-models-bucket"
$env:MLFLOW_S3_PREFIX = "models"

# Start MLflow server (Terminal 1)
Write-Host "Starting MLflow server..."
Start-Process powershell -ArgumentList "mlflow ui --host 0.0.0.0 --port 5000"

# Wait for server to start
Start-Sleep -Seconds 3

# Run training (Terminal 2)
Write-Host "Running training with S3 upload..."
python train_with_mlflow.py

# Verify S3 upload
Write-Host "`nVerifying S3 upload..."
python -m awscli s3 ls $env:MLFLOW_S3_BUCKET --recursive
```

Run with:
```powershell
.\run_training_with_s3.ps1
```

## 🎓 Next Steps

1. ✅ Configure AWS credentials
2. ✅ Create S3 bucket
3. ✅ Set MLFLOW_S3_BUCKET environment variable
4. ✅ Run `python train_with_mlflow.py`
5. ✅ Verify models uploaded to S3
6. ✅ Download and test model from S3

## 📖 References

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [MLflow Documentation](https://mlflow.org/docs/latest/)
- [AWS Access Keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)

---

**Questions?** Check your AWS IAM permissions and verify S3 bucket exists!
