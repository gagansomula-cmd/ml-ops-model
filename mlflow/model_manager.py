"""
MLflow Model Management and Inference

This script provides utilities for:
- Loading models from MLflow Registry
- Making predictions
- Managing model versions
- Comparing models
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional

import mlflow
import mlflow.sklearn
import numpy as np
import pandas as pd


class MLflowModelManager:
    """Manage and interact with MLflow models."""

    def __init__(self, tracking_uri: str = "http://localhost:5000"):
        """Initialize model manager.
        
        Args:
            tracking_uri: MLflow tracking server URI
        """
        self.tracking_uri = tracking_uri
        mlflow.set_tracking_uri(tracking_uri)

    def list_experiments(self) -> pd.DataFrame:
        """List all experiments."""
        experiments = mlflow.search_experiments()
        df = pd.DataFrame([
            {
                "id": exp.experiment_id,
                "name": exp.name,
                "artifact_location": exp.artifact_location,
                "lifecycle_stage": exp.lifecycle_stage,
            }
            for exp in experiments
        ])
        return df

    def list_registered_models(self) -> List[str]:
        """List all registered models."""
        from mlflow.tracking import MlflowClient
        client = MlflowClient(tracking_uri=self.tracking_uri)
        models = client.search_registered_models()
        return [m.name for m in models]

    def get_model_versions(self, model_name: str) -> pd.DataFrame:
        """Get all versions of a model.
        
        Args:
            model_name: Name of the registered model
            
        Returns:
            DataFrame with model version details
        """
        from mlflow.tracking import MlflowClient
        client = MlflowClient(tracking_uri=self.tracking_uri)
        
        versions = client.search_model_versions(f"name='{model_name}'")
        
        df = pd.DataFrame([
            {
                "version": v.version,
                "stage": v.current_stage,
                "created_timestamp": v.creation_timestamp,
                "run_id": v.run_id,
                "description": v.description,
                "status": v.status,
            }
            for v in versions
        ])
        
        return df.sort_values("version", ascending=False)

    def load_model(self, model_name: str, stage: str = "Production"):
        """Load a model from registry.
        
        Args:
            model_name: Name of the registered model
            stage: Stage of the model (Development, Staging, Production)
            
        Returns:
            Loaded model
        """
        try:
            model_uri = f"models:/{model_name}/{stage}"
            model = mlflow.sklearn.load_model(model_uri)
            print(f"✅ Loaded {model_name} ({stage})")
            return model
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            return None

    def load_model_by_version(self, model_name: str, version: str):
        """Load a specific model version.
        
        Args:
            model_name: Name of the registered model
            version: Version number
            
        Returns:
            Loaded model
        """
        try:
            model_uri = f"models:/{model_name}/{version}"
            model = mlflow.sklearn.load_model(model_uri)
            print(f"✅ Loaded {model_name} (v{version})")
            return model
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            return None

    def load_model_from_run(self, run_id: str, model_path: str = "model"):
        """Load model from a specific run.
        
        Args:
            run_id: MLflow run ID
            model_path: Path to model artifact
            
        Returns:
            Loaded model
        """
        try:
            model_uri = f"runs:/{run_id}/{model_path}"
            model = mlflow.sklearn.load_model(model_uri)
            print(f"✅ Loaded model from run {run_id}")
            return model
        except Exception as e:
            print(f"❌ Error loading model: {e}")
            return None

    def get_run_details(self, run_id: str) -> Dict:
        """Get details of a specific run.
        
        Args:
            run_id: MLflow run ID
            
        Returns:
            Dictionary with run details
        """
        run = mlflow.get_run(run_id)
        
        return {
            "run_id": run.info.run_id,
            "experiment_id": run.info.experiment_id,
            "status": run.info.status,
            "start_time": run.info.start_time,
            "end_time": run.info.end_time,
            "parameters": dict(run.data.params),
            "metrics": dict(run.data.metrics),
            "tags": dict(run.data.tags),
        }

    def search_best_run(self, experiment_id: str, metric_name: str) -> Dict:
        """Find best run based on a metric.
        
        Args:
            experiment_id: MLflow experiment ID
            metric_name: Metric to optimize
            
        Returns:
            Best run details
        """
        runs = mlflow.search_runs(
            experiment_ids=[experiment_id],
            order_by=[f"metrics.{metric_name} DESC"]
        )
        
        if runs.empty:
            print("No runs found")
            return None
        
        best_run = runs.iloc[0]
        run_id = best_run["run_id"]
        
        return self.get_run_details(run_id)

    def compare_runs(self, experiment_id: str, metric_name: str, top_n: int = 5) -> pd.DataFrame:
        """Compare top N runs based on a metric.
        
        Args:
            experiment_id: MLflow experiment ID
            metric_name: Metric to compare
            top_n: Number of top runs to compare
            
        Returns:
            DataFrame comparing runs
        """
        runs = mlflow.search_runs(
            experiment_ids=[experiment_id],
            order_by=[f"metrics.{metric_name} DESC"]
        )
        
        if runs.empty:
            print("No runs found")
            return None
        
        runs = runs.head(top_n)
        
        # Extract relevant columns
        result = runs[[
            "run_id",
            f"metrics.{metric_name}",
            "tags.mlflow.runName",
        ]].copy()
        
        result.columns = ["run_id", metric_name, "run_name"]
        
        return result

    def make_predictions(self, model, X: np.ndarray) -> np.ndarray:
        """Make predictions using loaded model.
        
        Args:
            model: Loaded MLflow model
            X: Input features
            
        Returns:
            Predictions
        """
        predictions = model.predict(X)
        return predictions

    def register_model(self, run_id: str, artifact_path: str, 
                      model_name: str, description: str = None):
        """Register a model from a run.
        
        Args:
            run_id: MLflow run ID
            artifact_path: Path to model artifact
            model_name: Name for the registered model
            description: Model description
        """
        try:
            model_uri = f"runs:/{run_id}/{artifact_path}"
            mlflow.register_model(model_uri, model_name)
            
            if description:
                from mlflow.tracking import MlflowClient
                client = MlflowClient(tracking_uri=self.tracking_uri)
                client.update_registered_model(model_name, description)
            
            print(f"✅ Registered model: {model_name}")
        except Exception as e:
            print(f"❌ Error registering model: {e}")

    def transition_model_stage(self, model_name: str, version: str, 
                              new_stage: str):
        """Transition model to a new stage.
        
        Args:
            model_name: Name of the registered model
            version: Model version
            new_stage: New stage (Development, Staging, Production, Archived)
        """
        try:
            from mlflow.tracking import MlflowClient
            client = MlflowClient(tracking_uri=self.tracking_uri)
            client.transition_model_version_stage(
                model_name, version, new_stage
            )
            print(f"✅ Transitioned {model_name} v{version} to {new_stage}")
        except Exception as e:
            print(f"❌ Error transitioning model: {e}")

    def print_experiment_summary(self, experiment_name: str):
        """Print summary of an experiment."""
        experiment = mlflow.get_experiment_by_name(experiment_name)
        
        if not experiment:
            print(f"Experiment '{experiment_name}' not found")
            return
        
        runs = mlflow.search_runs(experiment_ids=[experiment.experiment_id])
        
        print(f"\n{'='*60}")
        print(f"Experiment: {experiment_name}")
        print(f"{'='*60}")
        print(f"Total runs: {len(runs)}")
        
        if not runs.empty:
            print("\nTop runs:")
            print(runs[["run_id", "status", "start_time"]].head(5).to_string())


def main():
    """Demo of model management."""
    print("\n" + "="*60)
    print("MLflow Model Manager Demo")
    print("="*60 + "\n")
    
    manager = MLflowModelManager()
    
    # List experiments
    print("📊 Available Experiments:")
    print("-" * 60)
    experiments = manager.list_experiments()
    print(experiments.to_string(index=False))
    
    # List registered models
    print("\n📦 Registered Models:")
    print("-" * 60)
    models = manager.list_registered_models()
    for model in models:
        print(f"  - {model}")
        versions = manager.get_model_versions(model)
        print(versions.to_string(index=False))
        print()
    
    # Print experiment summary if available
    if not experiments.empty:
        first_exp = experiments.iloc[0]["name"]
        manager.print_experiment_summary(first_exp)
    
    print("\n" + "="*60)
    print("Demo complete!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
