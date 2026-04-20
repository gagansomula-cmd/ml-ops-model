#!/usr/bin/env powershell
<#
.SYNOPSIS
Configure S3 for MLflow model uploads

.DESCRIPTION
Sets up AWS credentials and MLflow S3 configuration for automatic model uploads

.EXAMPLE
.\configure_s3.ps1

.NOTES
Requires AWS credentials to be available or will prompt for them
#>

param(
    [string]$AccessKeyId,
    [string]$SecretAccessKey,
    [string]$Bucket,
    [string]$Region = "us-east-1",
    [string]$Prefix = "models"
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        MLflow S3 Configuration Setup                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# If parameters not provided, prompt for them
if (-not $AccessKeyId) {
    $AccessKeyId = Read-Host "Enter AWS Access Key ID"
}

if (-not $SecretAccessKey) {
    $SecretAccessKey = Read-Host "Enter AWS Secret Access Key" -AsSecureString
    $SecretAccessKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecretAccessKey))
}

if (-not $Bucket) {
    $Bucket = Read-Host "Enter S3 Bucket Name (e.g., my-ml-models)"
}

Write-Host "`n📋 Configuration Summary:" -ForegroundColor Green
Write-Host "  AWS Region: $Region"
Write-Host "  S3 Bucket: $Bucket"
Write-Host "  S3 Prefix: $Prefix"
Write-Host ""

$Confirm = Read-Host "Continue with this configuration? (y/n)"
if ($Confirm -ne 'y') {
    Write-Host "Configuration cancelled." -ForegroundColor Yellow
    exit 1
}

# Set environment variables
Write-Host "`n🔧 Setting environment variables..." -ForegroundColor Green

$env:AWS_ACCESS_KEY_ID = $AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $SecretAccessKey
$env:AWS_DEFAULT_REGION = $Region
$env:MLFLOW_S3_BUCKET = $Bucket
$env:MLFLOW_S3_PREFIX = $Prefix

# Verify AWS credentials by listing S3 buckets
Write-Host "`n✅ Verifying AWS credentials..." -ForegroundColor Green

try {
    $buckets = python -m awscli s3 ls 2>$null | Select-String $Bucket
    if ($buckets) {
        Write-Host "✅ Successfully connected to S3 bucket: $Bucket" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Bucket '$Bucket' not found. Creating it..." -ForegroundColor Yellow
        python -m awscli s3 mb "s3://$Bucket" --region $Region 2>$null
        if ($?) {
            Write-Host "✅ Bucket created: $Bucket" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to create bucket. Check your credentials." -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "❌ Error connecting to AWS: $_" -ForegroundColor Red
    Write-Host "   Please check your credentials." -ForegroundColor Red
    exit 1
}

# Create .env file for persistence
Write-Host "`n💾 Creating .env file..." -ForegroundColor Green

$EnvContent = @"
# AWS Credentials
AWS_ACCESS_KEY_ID=$AccessKeyId
AWS_SECRET_ACCESS_KEY=$SecretAccessKey
AWS_DEFAULT_REGION=$Region

# MLflow S3 Configuration
MLFLOW_S3_BUCKET=$Bucket
MLFLOW_S3_PREFIX=$Prefix
"@

$EnvFile = Join-Path $PSScriptRoot ".env"
Set-Content -Path $EnvFile -Value $EnvContent -Encoding UTF8

Write-Host "✅ .env file created at: $EnvFile" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  IMPORTANT: Keep .env file secure!" -ForegroundColor Yellow
Write-Host "   - Add to .gitignore (don't commit to Git)" -ForegroundColor Yellow
Write-Host "   - Don't share this file" -ForegroundColor Yellow
Write-Host ""

# Create startup script that loads env file
Write-Host "📝 Creating startup script..." -ForegroundColor Green

$StartupScript = @"
# Load environment variables from .env file
if (Test-Path '.\.env') {
    Write-Host "Loading S3 configuration from .env..." -ForegroundColor Green
    Get-Content .\.env | ForEach-Object {
        if (`$_ -match '^\s*([^#=]+)=(.*)$') {
            `[System.Environment]::SetEnvironmentVariable(`$matches[1], `$matches[2])
        }
    }
    Write-Host "✅ S3 configured!" -ForegroundColor Green
    Write-Host "   Bucket: `$(`$env:MLFLOW_S3_BUCKET)" -ForegroundColor Cyan
    Write-Host "   Prefix: `$(`$env:MLFLOW_S3_PREFIX)" -ForegroundColor Cyan
}

# Start MLflow server
Write-Host "`nStarting MLflow server..." -ForegroundColor Green
mlflow ui --host 0.0.0.0 --port 5000
"@

$ScriptFile = Join-Path $PSScriptRoot "start-training-with-s3.ps1"
Set-Content -Path $ScriptFile -Value $StartupScript -Encoding UTF8

Write-Host "✅ Startup script created: $ScriptFile" -ForegroundColor Green

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            ✅ Configuration Complete!                       ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📚 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run the startup script:" -ForegroundColor White
Write-Host "     .\start-training-with-s3.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. In another terminal, run training:" -ForegroundColor White
Write-Host "     python train_with_mlflow.py" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. View results at:" -ForegroundColor White
Write-Host "     http://localhost:5000" -ForegroundColor Yellow
Write-Host ""
Write-Host "  4. Verify S3 upload:" -ForegroundColor White
Write-Host "     python -m awscli s3 ls $Bucket --recursive" -ForegroundColor Yellow
Write-Host ""
