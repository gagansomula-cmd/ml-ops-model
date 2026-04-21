# Deployment Verification Checklist

This checklist helps you verify that the IAM role-based deployment is working correctly.

## ✅ Pre-Deployment Checks

### 1. GitHub Repository Setup
- [ ] GitHub OIDC provider exists in AWS Account
  ```bash
  aws iam list-open-id-connect-providers
  # Should show: oidc.github.com or token.actions.githubusercontent.com
  ```

- [ ] `AWS_ACCOUNT_ID` secret set in GitHub repository
  ```
  Settings → Secrets and variables → Actions → New repository secret
  Name: AWS_ACCOUNT_ID
  Value: Your AWS account ID (12 digits)
  ```

- [ ] Repository has push access to `main` branch (for workflow trigger)

### 2. AWS Account Configuration
- [ ] GitHub OIDC provider trusted in `terraform/github-oidc.tf`
  ```bash
  cd terraform
  terraform plan
  # Should show: GitHubActionsRole will be created
  ```

- [ ] S3 bucket exists for ML models
  ```bash
  aws s3 ls mlops-trainig-679631209574-us-east-1-an/
  # Should list bucket contents
  ```

- [ ] AWS account ID matches in all files
  ```bash
  grep -r "679631209574" .
  # All references should be to your account
  ```

## ✅ Initial Deployment (First Time)

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Expected**:
- EKS cluster created
- IAM roles created
- S3 bucket reference created
- aws-auth ConfigMap generated

### 2. Verify GitHub Actions Workflow Triggers
- [ ] Push changes to `main` branch:
  ```bash
  git add .
  git commit -m "Initial deployment"
  git push origin main
  ```

- [ ] Watch workflow in GitHub Actions
  - Go to: Repository → Actions → Terraform Deploy with OIDC
  - Wait for all steps to complete

**Expected Status**:
```
✅ Checkout code
✅ Configure AWS credentials with OIDC
✅ Setup Terraform
✅ Terraform Validate
✅ Terraform Plan
✅ Terraform Apply
✅ Apply aws-auth ConfigMap
✅ Deploy Helm components
✅ Deploy ML Model
✅ Verify deployment
```

## ✅ Post-Deployment Checks

### 1. Verify EKS Cluster

```bash
# Get cluster name from Terraform
CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
echo "Cluster: $CLUSTER_NAME"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1

# Check cluster status
kubectl cluster-info
# Should show: Kubernetes control plane is running

# List nodes
kubectl get nodes
# Should show: 2-3 worker nodes in Ready state

# List namespaces
kubectl get namespaces
# Should show: default, kube-system, kube-public, kserve, kubeflow, etc.
```

### 2. Verify aws-auth ConfigMap

```bash
# Check ConfigMap exists
kubectl get configmap aws-auth -n kube-system
# Should show: aws-auth ConfigMap found

# View ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# Should include:
# - Node role ARN (system:nodes group)
# - GitHub Actions role ARN (system:masters group)

# Verify GitHub Actions role mapping
kubectl get configmap aws-auth -n kube-system -o yaml | grep github-actions
# Should show: github-actions user mapped
```

### 3. Verify IAM Roles

```bash
# Check GitHubActionsRole exists
aws iam get-role --role-name GitHubActionsRole

# Check EKS node role
CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
aws ec2 describe-instances --filters "Name=tag:aws:eks:cluster-name,Values=$CLUSTER_NAME" \
  --query 'Reservations[].Instances[].IamInstanceProfile.Arn' --region us-east-1
# Should show: instance profile ARN
```

### 4. Verify S3 Access

```bash
# Check S3 bucket
S3_BUCKET=$(cd terraform && terraform output -raw ml_models_bucket)
echo "S3 Bucket: $S3_BUCKET"

aws s3 ls $S3_BUCKET/
# Should succeed (S3 bucket accessible)

# Check model exists
aws s3 ls s3://$S3_BUCKET/linear-regression/
# Should show: model.joblib (if model preparation completed)
```

### 5. Verify Helm Deployments

```bash
# List Helm releases
helm list --all-namespaces
# Should show:
# - cert-manager (cert-manager namespace)
# - istio-base, istiod (istio-system namespace)
# - sklearn-model (kserve namespace)

# Check specific release
helm status sklearn-model -n kserve
# Should show: Status: deployed

# Check release values
helm get values sklearn-model -n kserve
# Should show: S3 bucket, region, model storage URI
```

### 6. Verify KServe InferenceService

```bash
# List InferenceServices
kubectl get inferenceservice -n kserve
# Should show: sklearn-model with READY=True

# Check details
kubectl describe inferenceservice sklearn-model -n kserve
# Should show:
# - Status: ModelReady or InferenceReady
# - URL: http://sklearn-model.kserve.svc.cluster.local

# Watch pods deploy
kubectl get pods -n kserve -w
# Should show: predictor pods in Running state
# Wait 5-10 minutes for model to fully load

# Check logs
kubectl logs -n kserve -l app.kubernetes.io/name=sklearn-model -f
# Should show: "Model loaded successfully"
```

### 7. Verify Kubernetes RBAC

```bash
# Check system:masters group access
kubectl auth can-i '*' '*' --as=system:serviceaccount:default:default

# Check if current user has admin access
kubectl get clusterrolebindings | grep system:masters

# Verify role bindings
kubectl describe clusterrolebinding system:masters 2>/dev/null || \
  echo "system:masters binding via aws-auth ConfigMap"
```

## ✅ Security Verification

### 1. No Hardcoded Credentials

```bash
# Search for hardcoded AWS keys in repository
grep -r "AKIA" . --exclude-dir=.git 2>/dev/null
# Should return: (nothing found)

grep -r "aws_access_key" . --exclude-dir=.git 2>/dev/null
# Should return: (nothing found)

grep -r "AWS_SECRET_ACCESS_KEY" . --exclude-dir=.git 2>/dev/null
# Should return: (nothing found)
```

### 2. GitHub Actions OIDC Verification

```bash
# Check OIDC trust relationship
aws iam get-role --role-name GitHubActionsRole | \
  jq '.Role.AssumeRolePolicyDocument.Statement[].Condition'

# Should show:
# - StringLike condition with repository path
# - repo:owner/repo:ref:refs/heads/main
```

### 3. IAM Policy Verification

```bash
# Check GitHub Actions role policies
aws iam list-attached-role-policies --role-name GitHubActionsRole

# Should show:
# - IAMFullAccess
# - PowerUserAccess
# - AmazonEC2FullAccess
# - AmazonS3FullAccess

# Check inline policies
aws iam list-role-policies --role-name GitHubActionsRole

# Should show:
# - GitHubActionsTerraformPolicy
# - (possibly) github-actions-s3-models-access
```

### 4. S3 Access Verification

```bash
# Check EKS node role has S3 access
NODE_ROLE=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:eks:cluster-name,Values=$CLUSTER_NAME" \
  --query 'Reservations[].Instances[].IamInstanceProfile.Arn' \
  --output text --region us-east-1 | awk -F'/' '{print $NF}')

aws iam list-attached-role-policies --role-name $NODE_ROLE

# Should show:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - (possibly) eks-s3-models-access
```

## ✅ Model Preparation & Deployment

### 1. Check Model Preparation Script

```bash
# Test model preparation locally (requires AWS credentials)
python3 prepare_model.py \
  --json-path model_artifacts/linear_regression_model.json \
  --upload-s3 \
  --s3-bucket mlops-trainig-679631209574-us-east-1-an

# Should show:
# ✅ Model prepared and uploaded to S3
```

### 2. Verify Model in S3

```bash
S3_BUCKET=$(cd terraform && terraform output -raw ml_models_bucket)

# List model files
aws s3 ls s3://$S3_BUCKET/linear-regression/

# Download and verify
aws s3 cp s3://$S3_BUCKET/linear-regression/model.joblib /tmp/
file /tmp/model.joblib  # Should show: data (pickle file)
```

### 3. Verify InferenceService Configuration

```bash
# Check InferenceService YAML
kubectl get inferenceservice sklearn-model -n kserve -o yaml

# Should include:
# - storage_uri: s3://mlops-trainig-679631209574-us-east-1-an/linear-regression/model.joblib
# - protocol_version: v1
# - model_format: sklearn

# Check if service is getting traffic
kubectl get service -n kserve
# Should show: sklearn-model service endpoint
```

## ✅ Test Deployment

### 1. Port Forward to KServe Service

```bash
# Forward local port to KServe service
kubectl port-forward -n kserve svc/sklearn-model 8080:80 &
PF_PID=$!

# Test prediction (once model is loaded)
curl -X POST http://localhost:8080/v1/models/sklearn-model:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[1.0, 2.0, 3.0]]}'

# Should return: predictions from the model
# Kill port-forward
kill $PF_PID
```

### 2. Check CloudWatch Logs

```bash
# View KServe pod logs
kubectl logs -n kserve -l app.kubernetes.io/name=sklearn-model --tail=50

# Check for errors or success messages
# Should show: "Model loaded successfully" or similar
```

### 3. Monitor Pod Resources

```bash
# Check pod resource usage
kubectl top pods -n kserve

# Should show: reasonable CPU and memory usage

# Watch pod events
kubectl describe pod -n kserve -l app.kubernetes.io/name=sklearn-model

# Should show: Normal events, no errors or warnings
```

## 🚨 Troubleshooting Steps

### If workflow fails:

1. **Check GitHub Actions logs**:
   - Go to: Repository → Actions → Terraform Deploy with OIDC
   - Click failed workflow → View logs

2. **Common failures**:
   - OIDC token invalid → Verify AWS_ACCOUNT_ID secret
   - S3 permission denied → Check GitHub Actions role has S3 policy
   - kubeconfig not created → Check EKS cluster is ACTIVE
   - aws-auth not applied → Check ConfigMap YAML syntax

### If kubectl fails:

```bash
# Verify kubeconfig
cat ~/.kube/config | grep -A3 "current-context"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1

# Test authentication
aws sts get-caller-identity
# Should show: current IAM principal
```

### If S3 upload fails:

```bash
# Test S3 access directly
aws s3 ls mlops-trainig-679631209574-us-east-1-an/

# If fails → Check IAM role permissions in AWS console
# Role → Permissions → Check for s3-models-access policy
```

### If KServe pod fails to start:

```bash
# Check pod logs
kubectl logs -n kserve -l app.kubernetes.io/name=sklearn-model

# Check events
kubectl get events -n kserve --sort-by='.lastTimestamp'

# Describe pod for details
kubectl describe pod -n kserve <pod-name>
```

## ✅ Final Verification Command

Run this comprehensive check:

```bash
#!/bin/bash
set -e

echo "=== ML-Ops Deployment Verification ==="
echo ""

# 1. Check Cluster
echo "1. EKS Cluster Status:"
aws eks describe-cluster --name ml-ops-cluster --region us-east-1 \
  --query 'cluster.status' --output text
echo ""

# 2. Check Nodes
echo "2. Worker Nodes:"
kubectl get nodes --no-headers | wc -l
echo ""

# 3. Check Helm Releases
echo "3. Helm Deployments:"
helm list -A --output table
echo ""

# 4. Check InferenceService
echo "4. KServe InferenceService:"
kubectl get inferenceservice -n kserve
echo ""

# 5. Check aws-auth
echo "5. aws-auth ConfigMap:"
kubectl get configmap aws-auth -n kube-system --output json | \
  jq '.data.mapRoles' | head -5
echo ""

# 6. Check S3 Bucket
echo "6. S3 Model Storage:"
aws s3 ls mlops-trainig-679631209574-us-east-1-an/linear-regression/
echo ""

# 7. Check IAM Roles
echo "7. IAM Role Verification:"
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
echo ""

echo "✅ All checks completed!"
```

## 📊 Success Criteria

Your deployment is **SUCCESSFUL** when:

- [x] EKS cluster is ACTIVE
- [x] All worker nodes are Ready
- [x] aws-auth ConfigMap is applied
- [x] All Helm releases are deployed
- [x] KServe InferenceService is Ready
- [x] Model is downloaded from S3
- [x] Predictor pods are Running
- [x] GitHub Actions workflow completes successfully
- [x] No hardcoded AWS credentials in repository
- [x] IAM role-based authentication is working

🎉 Congratulations! Your ML-Ops infrastructure is fully deployed with enterprise-grade IAM role-based security!
