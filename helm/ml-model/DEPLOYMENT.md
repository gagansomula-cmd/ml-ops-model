# Helm Deployment Quick Start Guide

## Overview

This Helm chart deploys machine learning models on Kubernetes using:
- **KServe** for model inference
- **Kubeflow** for distributed training
- **AWS S3** for model storage
- **MLflow** for model registry

## Quick Commands

### 1. Deploy Sklearn Model (Inference Only)

```bash
cd ml-ops-model

# Update AWS account ID in values
sed -i 's/ACCOUNT_ID/679631209574/g' helm/ml-model/examples/inference-sklearn.yaml

# Install
helm install sklearn-model ./helm/ml-model \
  -f helm/ml-model/examples/inference-sklearn.yaml \
  -n kserve \
  --create-namespace

# Check status
helm list -n kserve
kubectl get inferenceservice -n kserve
```

### 2. Deploy PyTorch Model (with Training)

```bash
# Update AWS account ID
sed -i 's/ACCOUNT_ID/679631209574/g' helm/ml-model/examples/training-pytorch.yaml

# Install
helm install pytorch-model ./helm/ml-model \
  -f helm/ml-model/examples/training-pytorch.yaml \
  --create-namespace

# Watch training progress
kubectl get pods -n kubeflow -w
kubectl logs -n kubeflow -l job-name=pytorch-training -f
```

### 3. Deploy Complete Pipeline (Train + Infer)

```bash
# Update AWS account ID
sed -i 's/ACCOUNT_ID/679631209574/g' helm/ml-model/examples/pipeline-complete.yaml

# Install
helm install ml-pipeline ./helm/ml-model \
  -f helm/ml-model/examples/pipeline-complete.yaml \
  --create-namespace

# Monitor both training and inference
kubectl get pods -A
kubectl get inferenceservice -n kserve
kubectl get pytorchjob -n kubeflow
```

## Common Operations

### View Deployment Status

```bash
# List all Helm releases
helm list --all-namespaces

# Get specific release values
helm get values sklearn-model -n kserve

# Check inference service
kubectl get inferenceservice -n kserve -o wide
kubectl describe inferenceservice sklearn-model -n kserve
```

### Get Inference Endpoint

```bash
# Get the service URL
kubectl get inferenceservice sklearn-model -n kserve \
  -o jsonpath='{.status.url}'

# Example: http://sklearn-model.kserve.svc.cluster.local/v1/models/sklearn-model:predict
```

### Test Model Prediction

```bash
# Port forward for local testing
kubectl port-forward -n kserve svc/sklearn-model 8080:80

# In another terminal, test prediction
curl -X POST http://localhost:8080/v1/models/sklearn-model:predict \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [
      [5.1, 3.5, 1.4, 0.2],
      [7.0, 3.2, 4.7, 1.4]
    ]
  }'
```

### Monitor Logs

```bash
# Inference logs
kubectl logs -n kserve -l app.kubernetes.io/name=ml-model -f

# Training logs
kubectl logs -n kubeflow -l job-name=model-training -f

# All events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Update Model

```bash
# Update S3 path to new model
helm upgrade sklearn-model ./helm/ml-model \
  -f helm/ml-model/examples/inference-sklearn.yaml \
  --set inferenceService.model.storageUri="s3://ml-ops-models/sklearn/model-v2.pkl" \
  -n kserve

# Verify upgrade
helm get values sklearn-model -n kserve | grep storageUri
```

### Scale Model

```bash
# Increase max replicas
helm upgrade sklearn-model ./helm/ml-model \
  -f helm/ml-model/examples/inference-sklearn.yaml \
  --set inferenceService.autoscaling.maxReplicas=5 \
  -n kserve

# Check autoscaling
kubectl get hpa -n kserve
```

### Uninstall

```bash
# Remove deployment
helm uninstall sklearn-model -n kserve

# Verify removal
kubectl get inferenceservice -n kserve
```

## Configuration Examples

### Change Model Storage

```bash
helm upgrade sklearn-model ./helm/ml-model \
  --set inferenceService.model.storageUri="s3://my-bucket/my-model.pkl" \
  -n kserve
```

### Adjust Resources

```bash
helm upgrade sklearn-model ./helm/ml-model \
  --set inferenceService.resources.limits.cpu="2" \
  --set inferenceService.resources.limits.memory="4Gi" \
  -n kserve
```

### Enable Auto-scaling

```bash
helm upgrade sklearn-model ./helm/ml-model \
  --set inferenceService.autoscaling.minReplicas=2 \
  --set inferenceService.autoscaling.maxReplicas=10 \
  -n kserve
```

## Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod <pod-name> -n kserve
kubectl logs <pod-name> -n kserve
```

### Model Not Found

```bash
# Test S3 access
kubectl exec -it <pod-name> -n kserve -- aws s3 ls s3://ml-ops-models/

# Check IAM role
kubectl describe sa kserve-models-sa -n kserve
```

### Inference Failing

```bash
# Check service
kubectl get svc -n kserve

# Check logs
kubectl logs -n kserve -l app.kubernetes.io/name=ml-model -f

# Port-forward and test locally
kubectl port-forward -n kserve svc/sklearn-model 8080:80
```

## Integration with GitHub Actions

Add to `.github/workflows/deploy.yml`:

```yaml
- name: Deploy ML Model
  run: |
    helm repo add local ./helm/ml-model
    
    helm install ml-model ./helm/ml-model \
      -f helm/ml-model/examples/inference-sklearn.yaml \
      -n kserve \
      --create-namespace \
      --wait
    
    # Wait for deployment
    kubectl rollout status deployment -n kserve
```

## Next Steps

1. Update AWS account ID in example values
2. Update S3 bucket and model paths
3. Deploy using `helm install` commands above
4. Test predictions using curl commands
5. Monitor with `kubectl` commands
6. Integrate with CI/CD pipeline

## Resources

- [KServe Documentation](https://kserve.github.io/)
- [Helm Documentation](https://helm.sh/)
- [Kubernetes Documentation](https://kubernetes.io/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
