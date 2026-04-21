# EKS IAM Role Authentication Troubleshooting Guide

## 🔴 Problem: "The server has asked for the client to provide credentials"

### Error Message
```
E0421 13:25:19.381746    2811 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: the server has asked for the client to provide credentials"
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

### Root Cause
This error occurs when **kubectl tries to authenticate with Kubernetes before the aws-auth ConfigMap has been applied AND propagated**. There are multiple potential causes:

1. **Kubernetes API not ready** - EKS cluster is ACTIVE but the API isn't responding yet
2. **aws-auth ConfigMap not applied** - File not created, file path wrong, or kubectl apply failed
3. **aws-auth ConfigMap not propagated** - ConfigMap applied but IAM role mapping not yet active
4. **Wrong IAM role ARN** - ConfigMap has incorrect role ARN that doesn't match GitHub Actions role
5. **kubeconfig re-created** - Existing kubeconfig deleted before authentication ready

---

## ✅ Solution: Enhanced Authentication Flow

The workflow has been updated with **5 critical steps** to ensure proper authentication:

### Step 1: Verify aws-auth ConfigMap Generation
**Location**: Before any kubectl commands
**Purpose**: Ensure aws-auth-configmap.yaml exists and has correct role ARN
**Actions**:
- Checks if file exists
- Shows file contents
- Compares GitHub Actions role ARN from Terraform with ConfigMap contents

**Troubleshooting**:
```bash
# If aws-auth-configmap.yaml not found:
# 1. Check Terraform ran successfully:
cd terraform
terraform output github_actions_role_arn
terraform output cluster_name

# 2. Check if file was generated:
ls -la aws-auth-configmap.yaml
cat aws-auth-configmap.yaml
```

### Step 2: Wait for Kubernetes API Ready
**Location**: After cluster is ACTIVE
**Purpose**: Wait for Kubernetes API endpoint to respond
**Retry Logic**: 60 attempts, 5 seconds apart (5 minutes max)
**Test**: HTTP request to cluster endpoint `/healthz` endpoint

**Troubleshooting**:
```bash
# Get cluster endpoint
CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region us-east-1 --query cluster.endpoint --output text)

# Test API responsiveness
curl -k $ENDPOINT/healthz

# Expected output: "ok" or "healthy"
```

### Step 3: Apply aws-auth ConfigMap
**Location**: After API is ready
**Purpose**: Apply ConfigMap that maps IAM roles to Kubernetes
**Includes**:
- Searches multiple paths for ConfigMap file
- Shows full ConfigMap content before applying
- Verifies ConfigMap was applied
- Shows role mappings in ConfigMap

**Troubleshooting**:
```bash
# Verify ConfigMap was applied
kubectl get configmap aws-auth -n kube-system

# Show full ConfigMap content
kubectl get configmap aws-auth -n kube-system -o yaml

# Check role mappings specifically
kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}'

# Verify your role ARN is in the mapping
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsRole --query Role.Arn --output text)
kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' | grep "$ROLE_ARN"
```

### Step 4: Wait for Kubectl Authentication Ready
**Location**: After aws-auth ConfigMap applied
**Purpose**: Wait for IAM role authorization to propagate
**Duration**: Up to 2 minutes (60 attempts, 2 seconds apart)
**Why**: Even after applying aws-auth, Kubernetes needs 30-120 seconds to:
  - Recognize the new role mapping
  - Cache the authorization
  - Allow authenticated kubectl requests

**Troubleshooting**:
```bash
# Test kubectl commands iteratively
for i in {1..60}; do
  echo "Attempt $i..."
  kubectl get pods -n default && echo "✅ Success!" && break
  sleep 2
done

# If still failing, check the ConfigMap again
kubectl get configmap aws-auth -n kube-system -o yaml | grep -A5 "github-actions"
```

### Step 5: Deploy with Helm (Reuse kubeconfig)
**Location**: After kubectl authentication verified
**Purpose**: Deploy ML model using authenticated kubeconfig
**Critical Change**: Reuses existing kubeconfig instead of recreating it
**Why**: Deleting and recreating kubeconfig loses authentication context

**Troubleshooting**:
```bash
# Verify kubeconfig exists and has correct context
kubectl config view

# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts
```

---

## 🔍 Debugging Checklist

If you still get authentication errors, check in order:

### 1. Is the cluster ACTIVE?
```bash
aws eks describe-cluster --name ml-ops-cluster --region us-east-1 \
  --query cluster.status --output text
# Expected: ACTIVE
```

### 2. Is the Kubernetes API responding?
```bash
ENDPOINT=$(aws eks describe-cluster --name ml-ops-cluster --region us-east-1 \
  --query cluster.endpoint --output text)
curl -k "$ENDPOINT/healthz"
# Expected: "ok" or "healthy"
```

### 3. Is aws-auth ConfigMap applied?
```bash
kubectl get configmap aws-auth -n kube-system
# Expected: aws-auth listed
```

### 4. Does aws-auth have the correct role ARN?
```bash
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsRole --query Role.Arn --output text)
echo "Role ARN: $ROLE_ARN"

kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' | grep "$ROLE_ARN"
# Expected: Role ARN appears in output
```

### 5. Is the role mapped to system:masters?
```bash
kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' | grep -A2 "$ROLE_ARN"
# Expected: "groups": ["system:masters"]
```

### 6. Can kubectl actually execute commands?
```bash
kubectl get pods -n default
# Expected: Pod list or "No resources found"
```

---

## 📋 GitHub Actions Workflow Steps (Updated Order)

```
1. ✅ Terraform Apply
2. ✅ Get EKS Cluster Endpoint (wait for ACTIVE)
3. ✅ Verify EKS Deployment (AWS API checks)
4. ✅ Configure kubectl (create kubeconfig)
5. ✅ Setup Helm
6. ✅ Verify aws-auth ConfigMap Generation ⭐ NEW
7. ✅ Wait for Kubernetes API Ready ⭐ NEW
8. ✅ Apply aws-auth ConfigMap ⭐ IMPROVED
9. ✅ Wait for Kubectl Authentication Ready ⭐ NEW
10. ✅ Deploy Cert-Manager (now kubectl is ready!)
11. ✅ Deploy Istio
12. ✅ Deploy KServe
13. ✅ Deploy Kubeflow
14. ✅ Prepare ML Model
15. ✅ Deploy ML Model with Helm (reuses kubeconfig)
16. ✅ Verify ML Model Deployment
```

---

## 🎯 Key Timeline

| Time | Event |
|------|-------|
| 0 min | Terraform Apply starts |
| ~3 min | EKS cluster enters ACTIVE state |
| ~3.5 min | Kubernetes API starts responding |
| ~4 min | aws-auth ConfigMap applied to cluster |
| ~4.5-6 min | **IAM role authorization propagates** (30-120s delay!) |
| ~5-6 min | kubectl commands start succeeding |
| ~6+ min | Helm deployment can proceed |

**Critical**: The 30-120 second propagation delay after applying aws-auth is normal and expected!

---

## 🛠️ Manual Fix If Workflow Fails

If the workflow fails at the kubectl step, you can manually fix it:

```bash
# 1. Get the aws-auth ConfigMap file
git clone <your-repo>
cd ml-ops-model

# 2. Update kubeconfig
aws eks update-kubeconfig --name ml-ops-cluster --region us-east-1

# 3. Apply aws-auth ConfigMap
kubectl apply -f aws-auth-configmap.yaml

# 4. Wait for propagation
sleep 120

# 5. Verify
kubectl get configmap aws-auth -n kube-system -o yaml

# 6. Deploy Helm chart
helm install sklearn-model helm/ml-model -n kserve --create-namespace
```

---

## 📊 Expected Workflow Output

### ✅ Success Indicators
```
✅ aws-auth-configmap.yaml found
✅ API server is responding
✅ ConfigMap exists
✅ GitHub Actions role is mapped to system:masters
✅ kubectl is fully authenticated
✅ Helm install succeeded
```

### ❌ Failure Indicators
```
❌ aws-auth-configmap.yaml not found
❌ API server not responding
❌ kubectl connection failed
❌ GitHub Actions role ARN NOT found in ConfigMap
❌ Failed to apply aws-auth ConfigMap
```

---

## 🔐 Security Verification

After successful authentication, verify:

```bash
# 1. Confirm GitHub Actions role is mapped
kubectl get configmap aws-auth -n kube-system -o yaml | grep -A3 "github-actions"

# 2. Confirm it has admin access
kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' | \
  grep -A2 "github-actions" | grep "system:masters"

# 3. Verify no hardcoded credentials
grep -r "AKIA" . --exclude-dir=.git 2>/dev/null || echo "✅ No hardcoded keys found"

# 4. Check that EKS nodes are also mapped
kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' | \
  grep -q "system:nodes" && echo "✅ Node role mapped"
```

---

## 📞 Common Issues & Solutions

### Issue: "couldn't get current server API group list"
**Cause**: aws-auth ConfigMap not applied or not propagated yet
**Solution**: Wait 2-3 minutes after ConfigMap is applied

### Issue: "error: Unable to connect to the server"
**Cause**: Kubernetes API not ready
**Solution**: Wait 5+ minutes after cluster marked ACTIVE

### Issue: "user cannot impersonate resource"
**Cause**: GitHub Actions role not in aws-auth mapping
**Solution**: Verify role ARN in aws-auth ConfigMap matches actual role

### Issue: "role/GitHubActionsRole not found"
**Cause**: Terraform github-oidc.tf didn't create the role
**Solution**: Check Terraform logs for errors, re-run `terraform apply`

### Issue: "aws-auth-configmap.yaml not found"
**Cause**: Terraform eks.tf didn't generate the file
**Solution**: Check if file is in root directory or terraform directory

---

**Last Updated**: April 21, 2026
**Status**: ✅ Comprehensive Fix Applied
