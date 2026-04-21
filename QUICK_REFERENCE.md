# Quick Reference Guide

## 🚀 Quick Start Commands

### Initial Deployment
```bash
# 1. Clone repository
git clone <your-repo>
cd ml-ops-model

# 2. Set GitHub secret
# Go to: Settings → Secrets and variables → Actions → New repository secret
# Name: AWS_ACCOUNT_ID
# Value: Your AWS account ID

# 3. Push to trigger workflow
git add .
git commit -m "Initial deployment"
git push origin main

# 4. Watch workflow
# Go to: Actions → Terraform Deploy with OIDC
```

### Post-Deployment Access
```bash
# Get cluster name from Terraform
cd terraform
CLUSTER_NAME=$(terraform output -raw cluster_name)
cd ..

# Configure kubectl
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1

# Verify access
kubectl get nodes
```

## 📊 Common Operations

### View Cluster Status
```bash
# Get cluster info
kubectl cluster-info

# List all pods
kubectl get pods -A

# List services
kubectl get svc -A

# Watch pod events
kubectl get events -A --sort-by='.lastTimestamp'
```

### View Model Deployment
```bash
# Check InferenceService
kubectl get inferenceservice -n kserve

# Get details
kubectl describe inferenceservice sklearn-model -n kserve

# Watch pods
kubectl get pods -n kserve -w

# Check logs
kubectl logs -n kserve -l app.kubernetes.io/name=sklearn-model -f
```

### Monitor Resources
```bash
# Pod resource usage
kubectl top pods -n kserve

# Node resource usage
kubectl top nodes

# Describe node
kubectl describe node <node-name>
```

### View Helm Deployments
```bash
# List releases
helm list -A

# Get release values
helm get values sklearn-model -n kserve

# Check release status
helm status sklearn-model -n kserve

# Upgrade release
helm upgrade sklearn-model helm/ml-model -n kserve \
  --set inferenceService.enabled=true
```

### Access S3 Models
```bash
# List bucket
aws s3 ls mlops-trainig-679631209574-us-east-1-an/

# Download model
aws s3 cp s3://mlops-trainig-679631209574-us-east-1-an/linear-regression/model.joblib ./

# Upload model
aws s3 cp model.joblib s3://mlops-trainig-679631209574-us-east-1-an/linear-regression/

# View bucket contents
aws s3 sync s3://mlops-trainig-679631209574-us-east-1-an/ . --dry-run
```

### Verify IAM Roles
```bash
# Check GitHub Actions role
aws iam get-role --role-name GitHubActionsRole

# List role policies
aws iam list-role-policies --role-name GitHubActionsRole

# Check EKS node role
aws ec2 describe-instances --filters "Name=tag:aws:eks:cluster-name,Values=$CLUSTER_NAME" \
  --query 'Reservations[].Instances[].IamInstanceProfile.Arn'

# Get caller identity
aws sts get-caller-identity
```

### Troubleshooting

```bash
# Check workflow logs
# Go to: Repository → Actions → Click failed workflow

# Verify kubeconfig
kubectl config view

# Test kubectl connection
kubectl cluster-info --verbose=9

# Check aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# View pod events
kubectl describe pod <pod-name> -n kserve

# Get pod logs
kubectl logs <pod-name> -n kserve

# Execute command in pod
kubectl exec -it <pod-name> -n kserve -- bash

# Test S3 from pod
kubectl exec -it <pod-name> -n kserve -- \
  aws s3 ls mlops-trainig-679631209574-us-east-1-an/
```

## 🔄 Update Workflows

### Update Infrastructure (Terraform)
```bash
# Modify terraform files
vi terraform/eks.tf

# Plan changes
cd terraform && terraform plan

# Apply changes
terraform apply

# Commit and push
git add terraform/
git commit -m "Update infrastructure"
git push origin main
```

### Update Model Deployment (Helm)
```bash
# Modify Helm values
vi helm/ml-model/values.yaml

# Update Helm release
helm upgrade sklearn-model helm/ml-model -n kserve \
  --values helm/ml-model/values.yaml

# OR commit and let workflow update
git add helm/
git commit -m "Update Helm chart"
git push origin main
```

### Update Model Code
```bash
# Prepare new model
python3 prepare_model.py \
  --upload-s3 \
  --s3-bucket mlops-trainig-679631209574-us-east-1-an

# OR trigger GitHub Actions workflow
git add prepare_model.py
git commit -m "Update model preparation script"
git push origin main
```

## 📈 Monitoring & Logging

### CloudWatch Logs
```bash
# List log groups
aws logs describe-log-groups --region us-east-1

# View logs
aws logs tail /aws/eks/<cluster-name> --follow --region us-east-1

# Filter logs
aws logs tail /aws/eks/<cluster-name> --filter-pattern "ERROR" --region us-east-1
```

### Prometheus Metrics (if enabled)
```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Access: http://localhost:9090
```

### Application Logs
```bash
# Follow KServe logs
kubectl logs -n kserve -f -l app.kubernetes.io/name=sklearn-model

# Follow all Helm components
kubectl logs -n cert-manager -f
kubectl logs -n istio-system -f

# Stream multiple logs
kubectl logs -n kserve -f --tail=100 <pod-name>
```

## 🧹 Cleanup Operations

### Delete Helm Release
```bash
helm uninstall sklearn-model -n kserve
```

### Delete Kubernetes Namespace
```bash
kubectl delete namespace kserve
```

### Destroy Infrastructure (Terraform)
```bash
cd terraform
terraform destroy
# Type 'yes' when prompted
```

### Remove aws-auth ConfigMap Entry
```bash
kubectl edit configmap aws-auth -n kube-system
# Remove the role mapping you want to delete
```

### Clean Up S3 Models
```bash
# Delete specific model
aws s3 rm s3://mlops-trainig-679631209574-us-east-1-an/linear-regression/model.joblib

# Delete entire prefix
aws s3 rm s3://mlops-trainig-679631209574-us-east-1-an/linear-regression/ --recursive
```

## 🔐 Security Operations

### Rotate Credentials
```bash
# Terraform handles temporary credentials automatically
# No manual rotation needed (STS tokens auto-expire)

# To force new credentials in GitHub Actions:
# Wait for current workflow to complete
# Push new commit (triggers new OIDC token request)
```

### Audit CloudTrail
```bash
# List recent API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$CLUSTER_NAME \
  --region us-east-1

# Filter by principal
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=GitHubActionsRole \
  --region us-east-1
```

### Review IAM Policies
```bash
# Get inline policies
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsTerraformPolicy

# Get attached policies
aws iam list-attached-role-policies --role-name GitHubActionsRole
```

## 📝 Configuration Files

### Key Configuration Locations
```
terraform/
├── github-oidc.tf          # OIDC provider, GitHubActionsRole
├── eks.tf                  # EKS cluster, node role, aws-auth
├── s3-models.tf            # S3 bucket, IAM policies
└── terraform.tfvars        # Terraform variables

helm/
└── ml-model/
    ├── Chart.yaml          # Helm chart metadata
    ├── values.yaml         # Default values (S3 bucket, etc.)
    └── templates/          # Kubernetes manifests

.github/
└── workflows/
    └── terraform.yml       # GitHub Actions workflow

prepare_model.py            # Model preparation script
```

### Environment Variables (GitHub Actions)
```bash
AWS_ACCOUNT_ID              # Secret: Your AWS account ID
AWS_REGION                  # Default: us-east-1 (in workflow)
KUBECONFIG                  # Auto: ~/.kube/config (in workflow)
```

### Environment Variables (Local)
```bash
AWS_PROFILE                 # If using named AWS profiles
AWS_REGION                  # Default: us-east-1
KUBECONFIG                  # Default: ~/.kube/config
```

## 🆘 Getting Help

### Documentation
- **Architecture**: See `ARCHITECTURE.md` for detailed diagrams
- **IAM Roles**: See `IAM_ROLES.md` for authentication flow
- **Verification**: See `DEPLOYMENT_VERIFICATION.md` for checklist
- **README**: See `README.md` for project overview

### Common Issues

**Issue**: `error: You must be logged in to the server`
```bash
# Solution: Verify aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system

# Or re-configure kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
```

**Issue**: `Access Denied` when uploading to S3
```bash
# Solution: Check IAM policy attachment
aws iam list-role-policies --role-name GitHubActionsRole
aws iam get-role-policy --role-name GitHubActionsRole \
  --policy-name github-actions-s3-models-access
```

**Issue**: KServe pod fails to start
```bash
# Solution: Check pod logs
kubectl logs -n kserve <pod-name>
kubectl describe pod <pod-name> -n kserve

# Check events
kubectl get events -n kserve --sort-by='.lastTimestamp'
```

**Issue**: Model not downloading from S3
```bash
# Solution: Verify node role has S3 access
kubectl exec -it <pod-name> -n kserve -- \
  aws s3 ls mlops-trainig-679631209574-us-east-1-an/
```

### Useful Resources
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [KServe Documentation](https://kserve.github.io/website/)
- [Helm Documentation](https://helm.sh/docs/)

## ✅ Daily Checks

### Morning Checklist
```bash
# 1. Verify cluster health
kubectl get nodes

# 2. Check running pods
kubectl get pods -A | grep -v Running

# 3. Monitor resources
kubectl top nodes
kubectl top pods -A | sort -k4 -rn | head -10

# 4. Check recent errors
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# 5. Verify model serving
kubectl get inferenceservice -n kserve
```

### Weekly Checklist
```bash
# 1. Review CloudTrail logs
aws cloudtrail lookup-events --region us-east-1 | head -20

# 2. Check IAM role policies
aws iam list-role-policies --role-name GitHubActionsRole

# 3. Verify S3 bucket
aws s3 ls mlops-trainig-679631209574-us-east-1-an/ --recursive

# 4. Test inference endpoint
curl -X POST http://sklearn-model.kserve.svc.cluster.local/v1/models/sklearn-model:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[1.0, 2.0, 3.0]]}'

# 5. Review Terraform state
cd terraform && terraform plan
```

---

**Last Updated**: April 21, 2026
**Version**: 1.0 (IAM Role-Based Authentication)
