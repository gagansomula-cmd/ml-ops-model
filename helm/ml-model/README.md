# ML Model Helm Chart

A Helm chart for deploying machine learning models on Kubernetes using KServe and Kubeflow.

## Features

- Deploy ML models using KServe InferenceService
- Support for multiple model formats (sklearn, PyTorch, TensorFlow, XGBoost, ONNX)
- Kubeflow training job support (PyTorchJob, TFJob, XGBoostJob)
- AWS S3 integration for model storage
- IAM role support for secure AWS access
- MLflow integration for model registry
- Auto-scaling and resource management
- Monitoring with Prometheus

## Prerequisites

- Kubernetes 1.20+
- KServe 0.10+
- Kubeflow 1.6+ (optional, for training jobs)
- Helm 3.0+

## Installation

### 1. Basic Inference Deployment

```bash
# Clone the repository
cd ml-ops/helm/ml-model

# Create custom values file
cp values.yaml my-values.yaml

# Edit my-values.yaml with your model details
# Update:
# - inferenceService.model.storageUri (S3 path)
# - inferenceService.namespace
# - AWS account ID in iamRoleArn

# Install the chart
helm install my-model . -f my-values.yaml -n kserve --create-namespace
```

### 2. Deployment with Training Job

```bash
# Edit values to enable training
sed -i 's/trainingJob:/trainingJob:\n  enabled: true/' my-values.yaml

# Install
helm install my-model . -f my-values.yaml
```

### 3. Using from GitHub Actions

Add to your `.github/workflows/deploy.yml`:

```yaml
- name: Deploy ML Model with Helm
  run: |
    helm repo add ml-ops ./helm/ml-model
    
    # Create values override
    cat > deploy-values.yaml << EOF
    inferenceService:
      model:
        storageUri: s3://\${{ env.MODEL_BUCKET }}/models/\${{ env.MODEL_VERSION }}/
    trainingJob:
      enabled: false
    EOF
    
    helm install ${{ env.MODEL_NAME }} ./helm/ml-model \
      -f deploy-values.yaml \
      -n kserve \
      --wait
```

## Configuration

### Key Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `inferenceService.enabled` | `true` | Enable KServe inference deployment |
| `inferenceService.model.format` | `sklearn` | Model format (sklearn, pytorch, tensorflow, xgboost, onnx) |
| `inferenceService.model.storageUri` | - | S3 path to model artifact |
| `inferenceService.resources.limits.cpu` | `1` | CPU limit for inference pod |
| `inferenceService.resources.limits.memory` | `2Gi` | Memory limit for inference pod |
| `inferenceService.autoscaling.minReplicas` | `1` | Minimum replicas |
| `inferenceService.autoscaling.maxReplicas` | `3` | Maximum replicas |
| `trainingJob.enabled` | `false` | Enable training job |
| `trainingJob.type` | `pytorchjob` | Training job type |
| `aws.s3.bucket` | `ml-ops-models` | S3 bucket for models |

### Minimal Values Example

```yaml
inferenceService:
  model:
    name: my-model
    format: sklearn
    storageUri: s3://my-bucket/models/model.pkl

aws:
  s3:
    bucket: my-bucket
    region: us-east-1
    roleArn: arn:aws:iam::123456789:role/my-role
```

## Model Deployment Examples

### Deploy Sklearn Model

```yaml
inferenceService:
  name: iris-classifier
  model:
    format: sklearn
    storageUri: s3://ml-models/iris/model.pkl
```

### Deploy PyTorch Model

```yaml
inferenceService:
  name: pytorch-model
  model:
    format: pytorch
    storageUri: s3://ml-models/pytorch/model.pt
```

### Deploy TensorFlow Model

```yaml
inferenceService:
  name: tf-model
  model:
    format: tensorflow
    storageUri: s3://ml-models/tensorflow/saved_model/
```

### Deploy with Training Job

```yaml
trainingJob:
  enabled: true
  type: pytorchjob
  name: model-training
  
  master:
    replicas: 1
    resources:
      limits:
        cpu: 4
        memory: 8Gi
  
  worker:
    replicas: 2
    resources:
      limits:
        cpu: 4
        memory: 8Gi
  
  env:
    - name: MLFLOW_TRACKING_URI
      value: "http://mlflow-server:5000"
```

## Deployment Commands

### Install

```bash
helm install my-model ./helm/ml-model -f values.yaml -n kserve
```

### Upgrade

```bash
helm upgrade my-model ./helm/ml-model -f values.yaml -n kserve
```

### List Releases

```bash
helm list -n kserve
helm get values my-model -n kserve
```

### Uninstall

```bash
helm uninstall my-model -n kserve
```

### Dry Run (Preview)

```bash
helm install my-model ./helm/ml-model --dry-run --debug -f values.yaml
```

## Monitoring

### Check Deployment Status

```bash
# Check inference service
kubectl get inferenceservice -n kserve
kubectl describe inferenceservice my-model -n kserve

# Check pods
kubectl get pods -n kserve
kubectl logs -n kserve -l app.kubernetes.io/name=ml-model -f
```

### Get Inference Endpoint

```bash
kubectl get inferenceservice my-model -n kserve \
  -o jsonpath='{.status.url}'
```

### Test Prediction

```bash
# Get the service URL
SERVICE_URL=$(kubectl get inferenceservice my-model -n kserve -o jsonpath='{.status.url}')

# Send prediction request
curl -v -X POST $SERVICE_URL/v1/models/my-model:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[1.0, 2.0, 3.0]]}'
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n kserve

# Check logs
kubectl logs <pod-name> -n kserve

# Check events
kubectl get events -n kserve
```

### Model Not Found

```bash
# Verify S3 access
kubectl exec -it <pod-name> -n kserve -- aws s3 ls s3://bucket/path/

# Check IAM role
kubectl describe sa kserve-models-sa -n kserve
```

### Inference Not Working

```bash
# Check service status
kubectl get svc -n kserve

# Port forward for local testing
kubectl port-forward -n kserve svc/my-model 8080:80

# Test locally
curl http://localhost:8080/v1/models/my-model:predict
```

## Uninstallation

```bash
helm uninstall my-model -n kserve
```

This will remove:
- InferenceService
- ServiceAccount
- ConfigMap
- Training jobs (if enabled)

## Support

For issues and questions:
- KServe Documentation: https://kserve.github.io/
- Kubeflow Documentation: https://www.kubeflow.org/docs/
- Helm Documentation: https://helm.sh/docs/
