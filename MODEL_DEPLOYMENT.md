# ML Model Deployment Guide

## Overview

This guide explains how the ML model is deployed to your EKS cluster via Helm and KServe.

## Automatic Deployment (GitHub Actions)

When you push to `main`, the GitHub Actions workflow:

1. ✅ Provisions EKS cluster and supporting infrastructure (Terraform)
2. ✅ Configures kubectl access to the cluster
3. ✅ Deploys Cert-Manager (for TLS)
4. ✅ Deploys Istio (service mesh)
5. ✅ Deploys KServe (ML model serving)
6. ✅ Deploys Kubeflow (training orchestration)
7. ✅ **NEW**: Prepares ML model (JSON → sklearn pickle)
8. ✅ **NEW**: Uploads model to S3
9. ✅ Deploys model via Helm chart

## Manual Model Preparation

If you need to prepare the model locally before deployment:

```bash
# Install dependencies
pip install scikit-learn boto3

# Prepare and upload model
python3 prepare_model.py \
  --json-path model_artifacts/linear_regression_model.json \
  --output model_artifacts/model.joblib \
  --upload-s3 \
  --s3-bucket ml-ops-models \
  --s3-key linear-regression/model.joblib \
  --region us-east-1
```

## Verify Deployment

Once the workflow completes, verify the model is deployed:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name ml-ops-cluster --region us-east-1

# Check InferenceServices
kubectl get inferenceservice -n kserve

# Get detailed InferenceService status
kubectl describe inferenceservice sklearn-model -n kserve

# Check predictor pod status
kubectl get pods -n kserve -l app.kubernetes.io/name=ml-model

# View predictor logs
kubectl logs -n kserve -l app.kubernetes.io/name=ml-model -f
```

## Test Model Predictions

Once the InferenceService is ready (status shows URL):

```bash
# Get the inference endpoint
ENDPOINT=$(kubectl get inferenceservice sklearn-model -n kserve -o jsonpath='{.status.url}')
echo "Endpoint: $ENDPOINT"

# Test prediction (when ready)
curl -X POST "$ENDPOINT/v1/models/sklearn-model:predict" \
  -H "Content-Type: application/json" \
  -d '{"instances": [[2.5]]}'
```

## Troubleshooting

### InferenceService not created

Check the Helm deployment:
```bash
helm list -n kserve
helm status sklearn-model -n kserve
helm get values sklearn-model -n kserve
```

### Model not downloading from S3

Verify the S3 bucket exists and the model file is there:
```bash
aws s3 ls s3://ml-ops-models/linear-regression/
```

The IAM role must have S3 access. The service account has this annotation:
```yaml
iam.gke.io/gcp-service-account: ml-ops-sa@PROJECT_ID.iam.gserviceaccount.com
```

### KServe predictor pod not starting

Check pod logs:
```bash
kubectl logs -n kserve -l app.kubernetes.io/name=ml-model --all-containers=true

# Or check specific pod
kubectl logs -n kserve sklearn-model-predictor-default-xxxxx -c kserve-container
```

### Values/Configuration Issues

Update the Helm deployment values:
```bash
helm upgrade sklearn-model ./helm/ml-model \
  --set inferenceService.model.storageUri="s3://your-bucket/path/to/model.joblib" \
  -n kserve
```

## Model Configuration

The Helm chart uses these values for the model:

```yaml
inferenceService:
  enabled: true
  name: sklearn-model          # Name of the InferenceService
  namespace: kserve            # Kubernetes namespace
  
  model:
    format: sklearn            # Model format (sklearn, pytorch, tensorflow, xgboost, onnx)
    storageUri: "s3://..."     # S3 path to model file
```

See `helm/ml-model/values.yaml` for all available configuration options.

## Next Steps

1. **Train new models**: Use the training job templates in `helm/ml-model/examples/`
2. **Monitor predictions**: Set up Prometheus and Grafana for metrics
3. **Update models**: New model versions can be deployed by updating the `storageUri`
4. **Scale deployment**: Adjust `autoscaling` or `resources` in values

## Files

- `prepare_model.py` - Converts JSON model config to sklearn pickle
- `helm/ml-model/` - Helm chart for model deployment
- `.github/workflows/terraform.yml` - GitHub Actions workflow for full deployment
