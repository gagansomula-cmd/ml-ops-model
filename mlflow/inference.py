"""
MLflow Model Inference Examples

This script demonstrates how to:
- Load models from MLflow
- Make predictions
- Evaluate performance
"""

import numpy as np
from sklearn.metrics import mean_squared_error, r2_score
from model_manager import MLflowModelManager


def demo_inference():
    """Demonstrate model inference."""
    
    print("\n" + "="*60)
    print("MLflow Model Inference Demo")
    print("="*60 + "\n")
    
    manager = MLflowModelManager()
    
    # Generate sample data for inference
    np.random.seed(42)
    X_test = np.random.randn(10, 10)  # 10 samples, 10 features
    
    print("📊 Sample Data:")
    print(f"  Shape: {X_test.shape}")
    print(f"  First sample: {X_test[0]}")
    
    # List available models
    models = manager.list_registered_models()
    
    if not models:
        print("\n❌ No registered models found!")
        print("Run 'python train_with_mlflow.py' first to train models")
        return
    
    print(f"\n📦 Available Models: {models}")
    
    # Load and test each model
    for model_name in models:
        print(f"\n{'='*60}")
        print(f"Testing Model: {model_name}")
        print("="*60)
        
        # Get model versions
        versions = manager.get_model_versions(model_name)
        
        if versions.empty:
            print(f"  No versions found for {model_name}")
            continue
        
        print(f"  Available versions:")
        print(f"  {versions[['version', 'stage']].to_string(index=False)}")
        
        # Try loading Production version
        production_versions = versions[versions['stage'] == 'Production']
        
        if not production_versions.empty:
            model = manager.load_model(model_name, stage="Production")
        else:
            # Use latest version if no Production version
            latest_version = versions.iloc[0]['version']
            model = manager.load_model_by_version(model_name, str(latest_version))
        
        if model is None:
            continue
        
        # Make predictions
        print(f"\n  Making predictions...")
        predictions = manager.make_predictions(model, X_test)
        
        print(f"  Predictions shape: {predictions.shape}")
        print(f"  First 5 predictions:")
        print(f"  {predictions[:5]}")
        print(f"  Mean: {predictions.mean():.4f}, Std: {predictions.std():.4f}")
        
        # Get model details
        print(f"\n  Model Details:")
        if hasattr(model, 'coef_'):
            print(f"    Coefficients: {model.coef_[:3]}...")  # First 3
        if hasattr(model, 'intercept_'):
            print(f"    Intercept: {model.intercept_:.4f}")
    
    print(f"\n{'='*60}")
    print("Demo complete!")
    print("="*60 + "\n")


def demo_best_run():
    """Find and load the best run from an experiment."""
    
    print("\n" + "="*60)
    print("Finding Best Run Demo")
    print("="*60 + "\n")
    
    manager = MLflowModelManager()
    
    # Get first experiment
    experiments = manager.list_experiments()
    
    if experiments.empty:
        print("No experiments found")
        return
    
    experiment = experiments.iloc[0]
    exp_id = experiment['id']
    exp_name = experiment['name']
    
    print(f"Analyzing experiment: {exp_name}")
    
    # Find best run by R² score
    metric = "r2"
    best_run = manager.search_best_run(exp_id, metric)
    
    if best_run:
        print(f"\nBest run (by {metric}):")
        print(f"  Run ID: {best_run['run_id']}")
        print(f"  Status: {best_run['status']}")
        print(f"  Metrics:")
        for metric_name, metric_value in best_run['metrics'].items():
            print(f"    {metric_name}: {metric_value:.4f}")
        print(f"  Parameters:")
        for param_name, param_value in best_run['parameters'].items():
            print(f"    {param_name}: {param_value}")
    
    print()


def demo_compare_runs():
    """Compare top runs in an experiment."""
    
    print("\n" + "="*60)
    print("Comparing Top Runs Demo")
    print("="*60 + "\n")
    
    manager = MLflowModelManager()
    
    # Get first experiment
    experiments = manager.list_experiments()
    
    if experiments.empty:
        print("No experiments found")
        return
    
    experiment = experiments.iloc[0]
    exp_id = experiment['id']
    exp_name = experiment['name']
    
    print(f"Comparing runs in: {exp_name}")
    
    # Compare by R² score
    comparison = manager.compare_runs(exp_id, metric_name="r2", top_n=3)
    
    if comparison is not None:
        print("\nTop 3 runs by R² score:")
        print(comparison.to_string(index=False))
    
    print()


if __name__ == "__main__":
    # Run demos
    demo_best_run()
    demo_compare_runs()
    demo_inference()
