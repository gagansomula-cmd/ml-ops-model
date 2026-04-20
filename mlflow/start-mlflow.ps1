# MLflow Setup and Server Startup Script for PowerShell

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "        MLflow Local Setup and Server Startup" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is installed
try {
    python --version | Out-Null
} catch {
    Write-Host "❌ Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.8+ from https://www.python.org/"
    Read-Host "Press Enter to exit"
    exit 1
}

# Create virtual environment if it doesn't exist
if (-not (Test-Path "venv")) {
    Write-Host "📦 Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    & .\venv\Scripts\Activate.ps1
} else {
    Write-Host "✅ Virtual environment found" -ForegroundColor Green
    & .\venv\Scripts\Activate.ps1
}

# Upgrade pip
Write-Host "📥 Upgrading pip..." -ForegroundColor Yellow
python -m pip install --upgrade pip -q

# Install requirements
Write-Host "📥 Installing MLflow and dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -q

# Create necessary directories
if (-not (Test-Path "mlruns")) {
    Write-Host "📁 Creating mlruns directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "mlruns" | Out-Null
}

if (-not (Test-Path "artifacts")) {
    Write-Host "📁 Creating artifacts directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "artifacts" | Out-Null
}

# Display information
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "✅ Setup complete! Starting MLflow UI..." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 MLflow UI will be available at: http://localhost:5000" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run training experiments:" -ForegroundColor White
Write-Host "   python train_with_mlflow.py" -ForegroundColor Gray
Write-Host ""
Write-Host "To view model registry and experiments, visit:" -ForegroundColor White
Write-Host "   http://localhost:5000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Start MLflow UI
mlflow ui --host 0.0.0.0 --port 5000
