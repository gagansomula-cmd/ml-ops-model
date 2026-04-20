# MLflow Quick Start Guide

Get MLflow running on your local machine in under 5 minutes!

## 🚀 5-Minute Setup

### 1. Open PowerShell and navigate to mlflow directory

```powershell
cd g:\ml-ops\mlflow
```

### 2. Run the startup script

```powershell
.\start-mlflow.ps1
```

This will:
- ✅ Create virtual environment (if needed)
- ✅ Install all dependencies
- ✅ Start MLflow server on http://localhost:5000

### 3. Open browser and visit: http://localhost:5000

You should see the MLflow dashboard!

## 📊 Training Models

### In a NEW PowerShell window:

```powershell
cd g:\ml-ops\mlflow
.\venv\Scripts\Activate.ps1
python train_with_mlflow.py
```

This will:
- Train 2 different linear regression models
- Log parameters and metrics
- Register models in the registry
- Display results

Watch the training progress in your PowerShell window!

## 🔍 What to Explore in MLflow UI

### 1. **Experiments** (Main Page)
- See all experiments
- Click on experiment name to view runs

### 2. **Runs** (Inside Experiment)
- View all training runs
- Compare metrics side-by-side
- Download run data as CSV

### 3. **Run Details** (Inside Run)
- Parameters used
- Metrics achieved
- Artifacts logged
- Model information

### 4. **Models** (Model Registry)
- See registered models
- Manage versions
- Stage transitions (Dev → Prod)
- Model descriptions

## 💻 Quick Commands

```powershell
# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Run training
python train_with_mlflow.py

# Load and test models
python inference.py

# View model registry
python model_manager.py

# Deactivate
deactivate
```

## 📈 What Gets Logged

When you run `train_with_mlflow.py`, MLflow tracks:

**Parameters:**
- n_samples, n_features (data config)
- fit_intercept (model config)

**Metrics:**
- MSE (Mean Squared Error)
- RMSE (Root Mean Squared Error)
- MAE (Mean Absolute Error)
- R² (Coefficient of Determination)

**Artifacts:**
- Model coefficients (JSON)

**Models:**
- Sklearn model artifact
- Registered in Model Registry

## 🎯 Next Steps

1. ✅ **Run Training:** `python train_with_mlflow.py`
2. ✅ **Explore UI:** Open http://localhost:5000
3. ✅ **Compare Runs:** Go to experiment and compare metrics
4. ✅ **Load Models:** `python inference.py`
5. ✅ **Manage Registry:** Check Model Registry tab

## 🔗 Key Features

### ✨ Experiment Tracking
- Automatic logging of parameters
- Automatic logging of metrics
- Organize runs by experiment

### 📦 Model Registry
- Register trained models
- Manage versions
- Stage transitions
- Deployment ready

### 📊 Comparisons
- Compare any two runs
- Visualize metric differences
- Download comparison data

### 🔄 Model Serving
- Load any registered model
- Make predictions
- Track model usage

## 🐛 Troubleshooting

### "Connection refused" error?
- Make sure MLflow server is running: `.\start-mlflow.ps1`

### Scripts not running?
- Activate virtual environment: `.\venv\Scripts\Activate.ps1`
- Or run from PowerShell with proper execution policy

### Virtual environment issues?
```powershell
# Allow scripts to run
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Delete old venv and recreate
rm -r venv
.\start-mlflow.ps1
```

### Port 5000 in use?
```powershell
# Use different port
mlflow ui --port 5001
```

## 📚 File Overview

| File | Purpose |
|------|---------|
| `requirements.txt` | Python packages |
| `train_with_mlflow.py` | Training script |
| `model_manager.py` | Model management utilities |
| `inference.py` | Model loading and inference |
| `start-mlflow.ps1` | One-command setup script |
| `mlflow.conf` | Configuration file |

## 🎓 Learning Path

1. **Get it running** → Run `.\start-mlflow.ps1`
2. **Train models** → Run `python train_with_mlflow.py`
3. **Explore UI** → Visit http://localhost:5000
4. **Load models** → Run `python inference.py`
5. **Understand basics** → Read `README.md`
6. **Build custom** → Modify `train_with_mlflow.py`

## 💡 Key Concepts

**Experiment:** Collection of related runs (e.g., "linear-regression")

**Run:** Single training execution with parameters, metrics, and artifacts

**Parameter:** Configuration value (e.g., learning_rate, batch_size)

**Metric:** Performance measurement (e.g., accuracy, loss)

**Artifact:** Output file (e.g., model, plot, data)

**Model Registry:** Central catalog of models for production use

## 🚀 You're Ready!

Everything is set up and ready to use. Start with:

```powershell
.\start-mlflow.ps1
```

Then in another window:

```powershell
cd g:\ml-ops\mlflow
.\venv\Scripts\Activate.ps1
python train_with_mlflow.py
```

Visit http://localhost:5000 to see it in action!

---

**Need help?** Check `README.md` for detailed documentation.
