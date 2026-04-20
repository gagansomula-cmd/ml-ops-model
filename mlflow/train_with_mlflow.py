"""
MLflow Integration for Model Training

This script demonstrates how to use MLflow for:
- Experiment tracking
- Parameter logging
- Metric logging
- Model registration
- Artifact storage
- S3 model upload
"""

import json
import os
import pickle
import shutil
from pathlib import Path

import boto3
import mlflow
import mlflow.sklearn
import numpy as np
import pandas as pd
from botocore.exceptions import ClientError
from boto3.s3.transfer import S3Transfer, TransferConfig
from sklearn.datasets import make_regression
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler


class MLflowTrainer:
    """Train and log models with MLflow."""

    def __init__(self, experiment_name="ml-ops-linear-regression", s3_bucket=None):
        """Initialize MLflow trainer.
        
        Args:
            experiment_name: Name of the MLflow experiment
            s3_bucket: Optional S3 bucket for pushing models
        """
        self.experiment_name = experiment_name
        self.mlflow_uri = "http://localhost:5000"
        self.s3_bucket = s3_bucket or os.getenv('MLFLOW_S3_BUCKET')
        self.s3_prefix = os.getenv('MLFLOW_S3_PREFIX', 'models')
        
        # Set MLflow tracking URI
        mlflow.set_tracking_uri(self.mlflow_uri)
        
        # Create or get experiment
        self.experiment = self._get_or_create_experiment()
        
        # Initialize S3 client if bucket is specified
        self.s3_client = None
        if self.s3_bucket:
            try:
                self.s3_client = boto3.client('s3')
                print(f"✅ S3 configured: {self.s3_bucket}")
            except Exception as e:
                print(f"⚠️  S3 client error: {e}")
        else:
            print(f"ℹ️  S3 not configured. Models will be stored locally only.")
            print(f"   To enable S3, set MLFLOW_S3_BUCKET environment variable.")
        
    def _get_or_create_experiment(self):
        """Get existing experiment or create new one."""
        try:
            experiment = mlflow.get_experiment_by_name(self.experiment_name)
            if experiment is None:
                exp_id = mlflow.create_experiment(self.experiment_name)
                experiment = mlflow.get_experiment(exp_id)
            return experiment
        except Exception as e:
            print(f"Error with experiment: {e}")
            print("Make sure MLflow server is running: mlflow ui")
            raise

    def generate_synthetic_data(self, n_samples=1000, n_features=10, random_state=42):
        """Generate synthetic regression data.
        
        Args:
            n_samples: Number of samples
            n_features: Number of features
            random_state: Random seed
            
        Returns:
            X, y: Features and target
        """
        X, y = make_regression(
            n_samples=n_samples,
            n_features=n_features,
            n_informative=n_features // 2,
            noise=10,
            random_state=random_state
        )
        
        return X, y

    def preprocess_data(self, X, y, test_size=0.2, random_state=42):
        """Preprocess and split data.
        
        Args:
            X: Features
            y: Target
            test_size: Test set size
            random_state: Random seed
            
        Returns:
            X_train, X_test, y_train, y_test, scaler
        """
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state
        )
        
        # Scale features
        scaler = StandardScaler()
        X_train = scaler.fit_transform(X_train)
        X_test = scaler.transform(X_test)
        
        return X_train, X_test, y_train, y_test, scaler

    def train_model(self, X_train, y_train, **kwargs):
        """Train linear regression model.
        
        Args:
            X_train: Training features
            y_train: Training target
            **kwargs: Additional parameters for LinearRegression
            
        Returns:
            Trained model
        """
        model = LinearRegression(**kwargs)
        model.fit(X_train, y_train)
        return model

    def evaluate_model(self, model, X_test, y_test):
        """Evaluate model performance.
        
        Args:
            model: Trained model
            X_test: Test features
            y_test: Test target
            
        Returns:
            Dictionary of metrics
        """
        y_pred = model.predict(X_test)
        
        metrics = {
            "mse": mean_squared_error(y_test, y_pred),
            "rmse": np.sqrt(mean_squared_error(y_test, y_pred)),
            "mae": mean_absolute_error(y_test, y_pred),
            "r2": r2_score(y_test, y_pred),
        }
        
        return metrics, y_pred

    def push_to_s3(self, run_id, model_name):
        """Push model artifacts to S3 with optimized parallel uploads.
        
        Args:
            run_id: MLflow run ID
            model_name: Name of the model
            
        Returns:
            S3 location if successful, None otherwise
        """
        # Debug: Check if S3 is configured
        if not self.s3_bucket:
            print(f"\n⚠️  S3 not configured. Set MLFLOW_S3_BUCKET environment variable.")
            return None
        
        if not self.s3_client:
            print(f"\n❌ S3 client not initialized.")
            return None
        
        try:
            print(f"\n📤 Pushing model to S3...")
            print(f"   Bucket: {self.s3_bucket}")
            print(f"   Run ID: {run_id}")
            
            # Download model artifacts from MLflow server
            local_model_path = mlflow.artifacts.download_artifacts(
                run_id=run_id,
                artifact_path="linear_regression_model",
                dst_path="./mlflow_s3_temp"
            )
            
            if not os.path.exists(local_model_path):
                print(f"❌ Failed to download artifacts from MLflow server")
                return None
            
            # S3 prefix for this model
            s3_model_prefix = f"{self.s3_prefix}/{model_name}/{run_id}"
            
            # Configure S3 transfer for parallel uploads (faster!)
            config = TransferConfig(
                max_concurrency=10,  # 10 parallel threads
                multipart_threshold=8 * 1024 * 1024,  # 8 MB threshold for multipart
                multipart_chunksize=8 * 1024 * 1024,  # 8 MB chunks
            )
            
            transfer = S3Transfer(self.s3_client, config=config)
            
            # Upload all model files in parallel
            file_count = 0
            for root, dirs, files in os.walk(local_model_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    rel_path = os.path.relpath(file_path, local_model_path)
                    s3_key = f"{s3_model_prefix}/{rel_path}".replace(os.sep, "/")
                    
                    try:
                        print(f"   ⬆️  {rel_path}", end=" ", flush=True)
                        transfer.upload_file(file_path, self.s3_bucket, s3_key)
                        file_count += 1
                        print(f"✓")
                    except Exception as upload_error:
                        print(f"❌ Error: {upload_error}")
            
            # Clean up temporary directory
            if os.path.exists("./mlflow_s3_temp"):
                shutil.rmtree("./mlflow_s3_temp")
            
            if file_count == 0:
                print(f"   ⚠️  No files uploaded!")
                return None
            
            s3_location = f"s3://{self.s3_bucket}/{s3_model_prefix}"
            print(f"\n✅ Uploaded {file_count} files → {s3_location}")
            
            # Log S3 location to MLflow
            mlflow.log_param("s3_location", s3_location)
            
            return s3_location
            
        except ClientError as e:
            print(f"\n❌ AWS S3 Error: {e}")
            return None
        except Exception as e:
            print(f"\n❌ Error: {e}")
            return None

    def run_experiment(self, run_name="linear-regression-baseline", **model_params):
        """Run complete training experiment with MLflow tracking.
        
        Args:
            run_name: Name of the MLflow run
            **model_params: Parameters for the model
            
        Returns:
            Run info and results
        """
        print(f"\n{'='*60}")
        print(f"Starting MLflow Experiment: {self.experiment_name}")
        print(f"Run Name: {run_name}")
        print(f"{'='*60}\n")
        
        # Start MLflow run
        with mlflow.start_run(experiment_id=self.experiment.experiment_id):
            # Set run name
            mlflow.set_tag("mlflow.runName", run_name)
            
            # Log tags
            mlflow.set_tag("model_type", "linear_regression")
            mlflow.set_tag("environment", "development")
            mlflow.set_tag("framework", "scikit-learn")
            
            # Generate data
            print("📊 Generating synthetic data...")
            X, y = self.generate_synthetic_data()
            
            # Preprocess data
            print("🔧 Preprocessing data...")
            X_train, X_test, y_train, y_test, scaler = self.preprocess_data(X, y)
            
            # Log dataset info
            mlflow.log_param("n_samples", len(X))
            mlflow.log_param("n_features", X.shape[1])
            mlflow.log_param("test_size", 0.2)
            
            # Log model parameters
            print("⚙️  Logging model parameters...")
            for param, value in model_params.items():
                mlflow.log_param(param, value)
            
            # Train model
            print("🚀 Training model...")
            model = self.train_model(X_train, y_train, **model_params)
            
            # Evaluate model
            print("📈 Evaluating model...")
            metrics, y_pred = self.evaluate_model(model, X_test, y_test)
            
            # Log metrics
            for metric_name, metric_value in metrics.items():
                mlflow.log_metric(metric_name, metric_value)
                print(f"  {metric_name}: {metric_value:.4f}")
            
            # Log model coefficients as artifact
            print("💾 Logging artifacts...")
            coefficients = {
                "coefficients": model.coef_.tolist(),
                "intercept": float(model.intercept_),
            }
            
            # Save to temporary file
            artifacts_dir = Path("mlflow_artifacts")
            artifacts_dir.mkdir(exist_ok=True)
            
            with open(artifacts_dir / "model_coefficients.json", "w") as f:
                json.dump(coefficients, f, indent=2)
            
            mlflow.log_artifact(str(artifacts_dir / "model_coefficients.json"))
            
            # Log model with MLflow
            print("🔐 Logging model...")
            mlflow.sklearn.log_model(
                model,
                artifact_path="linear_regression_model",
                registered_model_name="linear-regression-baseline"
            )
            
            # Get run ID for S3 upload
            run_id = mlflow.active_run().info.run_id
            
            # Push to S3 if configured
            s3_location = self.push_to_s3(run_id, "linear-regression-baseline")
            
            # Clean up
            shutil.rmtree(artifacts_dir)
            
            print(f"\n✅ Run completed successfully!")
            print(f"View results at: {self.mlflow_uri}")
            
            return {
                "model": model,
                "metrics": metrics,
                "y_pred": y_pred,
                "scaler": scaler,
                "X_test": X_test,
                "y_test": y_test,
                "s3_location": s3_location,
            }

    def compare_experiments(self):
        """Compare all runs in the experiment."""
        print(f"\n{'='*60}")
        print(f"Experiment Runs: {self.experiment_name}")
        print(f"{'='*60}\n")
        
        # Get all runs
        runs = mlflow.search_runs(experiment_ids=[self.experiment.experiment_id])
        
        if runs.empty:
            print("No runs found in this experiment.")
            return
        
        # Display runs
        print(f"Total runs: {len(runs)}")
        print("\nRun Details:")
        print("-" * 100)
        
        for idx, run in runs.iterrows():
            print(f"\nRun {idx + 1}:")
            print(f"  ID: {run['run_id']}")
            print(f"  Name: {run.get('tags.mlflow.runName', 'N/A')}")
            print(f"  Status: {run['status']}")
            
            # Get metrics
            for col in runs.columns:
                if col.startswith("metrics."):
                    metric_name = col.replace("metrics.", "")
                    metric_value = run[col]
                    if pd.notna(metric_value):
                        print(f"  {metric_name}: {metric_value:.4f}")


def main():
    """Main training function."""
    import sys
    
    # Get S3 bucket from environment or command line
    s3_bucket = os.getenv('MLFLOW_S3_BUCKET', None)
    
    if s3_bucket:
        print(f"\n📦 S3 Configuration:")
        print(f"   Bucket: {s3_bucket}")
        print(f"   Prefix: {os.getenv('MLFLOW_S3_PREFIX', 'models')}")
    else:
        print(f"\n⚠️  S3 not configured. Models will only be stored locally.")
        print(f"   To enable S3 uploads, set MLFLOW_S3_BUCKET environment variable.")
    
    # Initialize trainer
    trainer = MLflowTrainer(experiment_name="ml-ops-linear-regression", s3_bucket=s3_bucket)
    
    # Experiment 1: Baseline model
    print("\n🔬 EXPERIMENT 1: Baseline Model")
    result1 = trainer.run_experiment(
        run_name="baseline-model",
        fit_intercept=True,
        n_jobs=-1,
    )
    
    # Experiment 2: Model with different parameters
    print("\n🔬 EXPERIMENT 2: Model without Intercept")
    result2 = trainer.run_experiment(
        run_name="no-intercept-model",
        fit_intercept=False,
        n_jobs=-1,
    )
    
    # Compare experiments
    trainer.compare_experiments()
    
    print(f"\n{'='*60}")
    print("✅ All experiments completed!")
    print(f"View detailed results at: {trainer.mlflow_uri}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
