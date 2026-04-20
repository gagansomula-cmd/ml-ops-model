@echo off
REM MLflow Setup and Server Startup Script for Windows

echo.
echo ================================================================
echo        MLflow Local Setup and Server Startup
echo ================================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://www.python.org/
    pause
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist venv (
    echo 📦 Creating virtual environment...
    python -m venv venv
    call venv\Scripts\activate.bat
) else (
    echo ✅ Virtual environment found
    call venv\Scripts\activate.bat
)

REM Upgrade pip
echo 📥 Upgrading pip...
python -m pip install --upgrade pip

REM Install requirements
echo 📥 Installing MLflow and dependencies...
pip install -r requirements.txt

REM Create necessary directories
if not exist mlruns (
    echo 📁 Creating mlruns directory...
    mkdir mlruns
)

if not exist artifacts (
    echo 📁 Creating artifacts directory...
    mkdir artifacts
)

REM Start MLflow UI
echo.
echo ================================================================
echo ✅ Setup complete! Starting MLflow UI...
echo ================================================================
echo.
echo 🚀 MLflow UI will be available at: http://localhost:5000
echo.
echo To run training experiments:
echo   python train_with_mlflow.py
echo.
echo To view model registry and experiments, visit:
echo   http://localhost:5000
echo.
echo Press Ctrl+C to stop the server
echo.
echo ================================================================
echo.

mlflow ui --host 0.0.0.0 --port 5000

pause
