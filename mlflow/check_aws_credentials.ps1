# AWS Credentials Diagnostic Script

Write-Host "================================" -ForegroundColor Cyan
Write-Host "AWS Credentials Diagnostic" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Check environment variables
Write-Host "1️⃣ Checking Environment Variables:" -ForegroundColor Yellow
$access_key = $env:AWS_ACCESS_KEY_ID
$secret_key = $env:AWS_SECRET_ACCESS_KEY
$region = $env:AWS_DEFAULT_REGION

if ($access_key) {
    Write-Host "   ✅ AWS_ACCESS_KEY_ID is SET (first 10 chars): $($access_key.Substring(0, [Math]::Min(10, $access_key.Length)))..."
} else {
    Write-Host "   ❌ AWS_ACCESS_KEY_ID is NOT SET" -ForegroundColor Red
}

if ($secret_key) {
    Write-Host "   ✅ AWS_SECRET_ACCESS_KEY is SET"
} else {
    Write-Host "   ❌ AWS_SECRET_ACCESS_KEY is NOT SET" -ForegroundColor Red
}

if ($region) {
    Write-Host "   ✅ AWS_DEFAULT_REGION is SET: $region"
} else {
    Write-Host "   ⚠️  AWS_DEFAULT_REGION is NOT SET (will use us-east-1)" -ForegroundColor Yellow
}

# Check AWS CLI config file
Write-Host "`n2️⃣ Checking AWS CLI Config File:" -ForegroundColor Yellow
$config_file = "$env:USERPROFILE\.aws\credentials"
if (Test-Path $config_file) {
    Write-Host "   ✅ AWS credentials file exists: $config_file"
    Write-Host "`n   Contents (redacted):"
    $content = Get-Content $config_file
    foreach ($line in $content) {
        if ($line -match 'aws_access_key_id') {
            Write-Host "      [Found aws_access_key_id]"
        } elseif ($line -match 'aws_secret_access_key') {
            Write-Host "      [Found aws_secret_access_key]"
        } else {
            Write-Host "      $line"
        }
    }
} else {
    Write-Host "   ❌ AWS credentials file NOT found at: $config_file" -ForegroundColor Red
}

# Test AWS credentials
Write-Host "`n3️⃣ Testing AWS Credentials:" -ForegroundColor Yellow
try {
    $result = python -m awscli s3 ls 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ AWS credentials are VALID!" -ForegroundColor Green
        Write-Host "`n   Your S3 buckets:"
        python -m awscli s3 ls
    } else {
        Write-Host "   ❌ AWS credentials are INVALID" -ForegroundColor Red
        Write-Host "   Error: $result"
    }
} catch {
    Write-Host "   ❌ Error testing credentials: $_" -ForegroundColor Red
}

# Recommendations
Write-Host "`n4️⃣ Recommendations:" -ForegroundColor Yellow

if (-not $access_key -or -not $secret_key) {
    Write-Host "   📝 Set environment variables:
    `$env:AWS_ACCESS_KEY_ID = 'your-access-key-id'
    `$env:AWS_SECRET_ACCESS_KEY = 'your-secret-access-key'
    `$env:AWS_DEFAULT_REGION = 'us-east-1'
    python train_with_mlflow.py`n" -ForegroundColor Cyan
}

Write-Host "   💡 Or use AWS CLI configure:
    python -m awscli configure`n" -ForegroundColor Cyan

Write-Host "================================`n" -ForegroundColor Cyan
