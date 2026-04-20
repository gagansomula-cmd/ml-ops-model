# MLflow Local Setup Guide

This directory contains everything needed to set up and run MLflow locally for experiment tracking, model registry, and machine learning lifecycle management.

## 📋 What is MLflow?

MLflow is an open-source platform that manages the end-to-end machine learning lifecycle:

- **Tracking**: Log parameters, metrics, and artifacts
- **Projects**: Package ML code in a reproducible format
- **Models**: Manage and serve models
- **Registry**: Central model store for model versioning and lifecycle

## 📁 Directory Structure

```
mlflow/
├── requirements.txt              # Python dependencies
├── mlflow.conf                   # MLflow configuration
├── train_with_mlflow.py         # Training script with MLflow tracking
├── start-mlflow.bat             # Windows batch script to start MLflow
├── start-mlflow.ps1             # PowerShell script to start MLflow
├── README.md                    # This file
├── mlruns/                      # MLflow experiment tracking directory (created)
└── artifacts/                   # Artifact storage directory (created)
```

## 🚀 Quick Start

### Step 1: Navigate to MLflow Directory

```powershell
cd g:\ml-ops\mlflow
```

### Step 2: Run Setup and Start Server

**Option A: PowerShell (Recommended)**

```powershell
# Allow script execution if needed
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the startup script
.\start-mlflow.ps1
```

**Option B: Command Prompt (CMD)**

```cmd
start-mlflow.bat
```

**Option C: Manual Setup**

```powershell
# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Start MLflow UI
mlflow ui --host 0.0.0.0 --port 5000
```

### Step 3: Access MLflow UI

Open your browser and navigate to: **http://localhost:5000**

You should see the MLflow dashboard with experiments and runs.

### Step 4: Run Training Experiments

In a **new PowerShell window** (keep the MLflow server running):

```powershell
cd g:\ml-ops\mlflow
.\venv\Scripts\Activate.ps1
python train_with_mlflow.py
```

This will:
- ✅ Create a new experiment
- ✅ Train multiple model variants
- ✅ Log parameters and metrics
- ✅ Register models in the model registry
- ✅ Store artifacts

## 📊 Using MLflow

### Basic Workflow

```python
import mlflow
from sklearn.linear_model import LinearRegression

# Set tracking URI (local file system)
mlflow.set_tracking_uri("http://localhost:5000")

# Create or get experiment
mlflow.set_experiment("my-experiment")

# Start a run
with mlflow.start_run():
    # Log parameters
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_param("batch_size", 32)
    
    # Train model
    model = LinearRegression()
    model.fit(X_train, y_train)
    
    # Log metrics
    mlflow.log_metric("accuracy", 0.95)
    mlflow.log_metric("loss", 0.05)
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
```

### Key Concepts

#### 1. Experiments

Group related runs together:

```python
mlflow.set_experiment("linear-regression")
mlflow.create_experiment("new-experiment")
experiments = mlflow.search_experiments()
```

#### 2. Runs

Individual training executions:

```python
with mlflow.start_run(run_name="baseline"):
    # Training code here
    pass
```

#### 3. Parameters

Hyperparameters and configuration:

```python
mlflow.log_param("learning_rate", 0.001)
mlflow.log_params({"epochs": 10, "batch_size": 32})
```

#### 4. Metrics

Performance measurements:

```python
mlflow.log_metric("accuracy", 0.95)
mlflow.log_metrics({"precision": 0.92, "recall": 0.89})
```

#### 5. Artifacts

Files (models, plots, data):

```python
mlflow.log_artifact("model.pkl")
mlflow.log_artifacts("plots/")
```

#### 6. Models

Register trained models:

```python
mlflow.sklearn.log_model(
    model,
    artifact_path="model",
    registered_model_name="my-model"
)
```

## 🎯 Features in the Demo

The `train_with_mlflow.py` script demonstrates:

✅ **Experiment Tracking**
- Log parameters (n_samples, n_features, etc.)
- Log metrics (MSE, RMSE, MAE, R²)
- Log artifacts (model coefficients)

✅ **Multiple Runs**
- Experiment 1: Baseline model
- Experiment 2: Model without intercept

✅ **Model Registry**
- Register models for production
- Track model versions
- Stage transitions (Development → Staging → Production)

✅ **Comparison**
- Compare metrics across runs
- View parameter differences
- Analyze performance trends

## 📈 MLflow UI Features

### Home Dashboard
- Quick access to recent experiments
- Search and filter runs
- Create new experiments

### Experiment View
- List all runs
- Compare run metrics and parameters
- Download data and models

### Run Details
- Parameter values
- Metric history (charts)
- Logged artifacts
- Model information

### Model Registry
- Register new models
- Manage model versions
- Stage transitions (Dev/Staging/Prod)
- Model descriptions and annotations

## 🔧 Configuration

### local File Storage (Default)

```
Backend: ./mlruns
Artifacts: ./artifacts
```

Perfect for local development.

### PostgreSQL Backend (Production)

```python
mlflow.set_tracking_uri("postgresql://user:password@localhost:5432/mlflow")
```

### Cloud Storage (AWS S3, Google Cloud, Azure)

```python
# AWS S3
mlflow.set_tracking_uri("s3://my-bucket/mlflow")

# Google Cloud Storage
mlflow.set_tracking_uri("gs://my-bucket/mlflow")

# Azure Blob Storage
mlflow.set_tracking_uri("wasbs://container@storage.blob.core.windows.net/mlflow")
```

## 📝 Advanced Examples

### 1. Log Custom Metrics

```python
import mlflow

with mlflow.start_run():
    for epoch in range(10):
        loss = train_epoch()
        mlflow.log_metric("loss", loss, step=epoch)
```

### 2. Compare Models

```python
from sklearn.linear_model import Ridge, Lasso

with mlflow.start_run(run_name="ridge"):
    model = Ridge(alpha=1.0)
    model.fit(X_train, y_train)
    mlflow.log_metric("r2", model.score(X_test, y_test))

with mlflow.start_run(run_name="lasso"):
    model = Lasso(alpha=1.0)
    model.fit(X_train, y_train)
    mlflow.log_metric("r2", model.score(X_test, y_test))
```

### 3. Load and Use Registered Models

```python
import mlflow.sklearn

# Load latest version
model = mlflow.sklearn.load_model("models:/my-model/latest")

# Load specific version
model = mlflow.sklearn.load_model("models:/my-model/1")

# Load production version
model = mlflow.sklearn.load_model("models:/my-model/Production")

# Make predictions
predictions = model.predict(X_test)
```

### 4. Auto-Log from Libraries

```python
# Automatically log sklearn models
mlflow.sklearn.autolog()
model = LinearRegression()
model.fit(X_train, y_train)  # Parameters and metrics auto-logged!

# Works with: sklearn, XGBoost, Keras, PyTorch, and more
```

## 🔍 Accessing Experiment Data Programmatically

```python
import mlflow

# Get all experiments
experiments = mlflow.search_experiments()

# Search runs
runs = mlflow.search_runs(
    experiment_ids=["1"],
    filter_string="metrics.accuracy > 0.9"
)

# Get run details
run = mlflow.get_run(run_id)
print(run.data.params)      # Parameters
print(run.data.metrics)     # Metrics
print(run.data.tags)        # Tags
```

## 🔐 Best Practices

✅ **Do:**
- Use descriptive experiment names
- Log all important parameters
- Use tags for categorization
- Register production models
- Document model purpose and usage
- Version your datasets

❌ **Don't:**
- Log sensitive data
- Skip parameter logging
- Use generic run names
- Forget to register good models
- Mix experiments in same run

## 🐛 Troubleshooting

### MLflow UI not loading

```powershell
# Check if server is running
netstat -ano | findstr :5000

# Kill existing process if needed
taskkill /PID <PID> /F

# Restart the server
.\start-mlflow.ps1
```

### Connection refused error

```
Error: Failed to connect to http://localhost:5000
```

Solution: Start the MLflow server first
```powershell
.\start-mlflow.ps1
```

### Virtual environment not activating

```powershell
# If activation fails, try:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then activate:
.\venv\Scripts\Activate.ps1
```

### Port already in use

```powershell
# Use a different port
mlflow ui --host 0.0.0.0 --port 5001
```

### Artifacts not saving

Check the `artifacts/` directory exists and has write permissions.

```powershell
mkdir artifacts
icacls artifacts /grant Users:F /T
```

## 📚 Additional Resources

- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [MLflow GitHub](https://github.com/mlflow/mlflow)
- [MLflow Tutorials](https://mlflow.org/docs/latest/tutorials-and-examples/index.html)
- [MLflow API Reference](https://mlflow.org/docs/latest/python_api/index.html)

## 🎓 Next Steps

1. ✅ Start MLflow server: `.\start-mlflow.ps1`
2. ✅ Run training experiments: `python train_with_mlflow.py`
3. ✅ View results at: http://localhost:5000
4. ✅ Explore the Model Registry
5. ✅ Integrate MLflow into your own training code

## 📞 Quick Commands

```powershell
# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Start MLflow server
mlflow ui --host 0.0.0.0 --port 5000

# Run training with MLflow
python train_with_mlflow.py

# Deactivate virtual environment
deactivate

# Delete all experiments (careful!)
# rm -r mlruns/
# rm -r artifacts/
```

## 📝 Notes

- MLflow uses local file storage by default (./mlruns and ./artifacts)
- For production, configure a database backend (PostgreSQL, MySQL)
- Models are stored as artifacts with metadata in mlruns/
- The Model Registry is built into the UI at http://localhost:5000/#/models

---

**Happy experimenting! 🚀**
