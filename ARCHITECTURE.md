# ML-Ops Architecture - Complete Overview

## 📐 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                                 │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ Code:                                                           │    │
│  │  - terraform/                  (Infrastructure as Code)         │    │
│  │  - helm/ml-model/              (Kubernetes deployment charts)   │    │
│  │  - prepare_model.py            (Model preparation script)       │    │
│  │  - .github/workflows/           (CI/CD automation)              │    │
│  │                                                                 │    │
│  │ ✅ NO HARDCODED CREDENTIALS IN CODE                           │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                      Git Push to main branch
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                        GitHub Actions (CI/CD)                            │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Checkout Code                                               │    │
│  │ 2. Request GitHub OIDC Token                                  │    │
│  │ 3. Assume GitHubActionsRole via AWS STS                       │    │
│  │ 4. Receive Temporary AWS Credentials                          │    │
│  │ 5. Run Terraform (EKS, IAM, VPC, S3)                          │    │
│  │ 6. Setup Kubernetes (aws-auth ConfigMap)                      │    │
│  │ 7. Deploy Helm Charts (Cert-Manager, Istio, KServe)           │    │
│  │ 8. Prepare ML Model (JSON → sklearn pickle)                   │    │
│  │ 9. Upload Model to S3                                          │    │
│  │ 10. Deploy KServe InferenceService                            │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                            AWS Account                                    │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────┐    │  │
│  │  │ GitHub OIDC Provider (IAM Trust)                      │    │  │
│  │  │ ├─ URL: token.actions.githubusercontent.com          │    │  │
│  │  │ ├─ Trust: repo:owner/repo:ref:refs/heads/main       │    │  │
│  │  │ └─ Service: STS (Security Token Service)             │    │  │
│  │  └────────────────────────────────────────────────────────┘    │  │
│  │                            ↓                                   │  │
│  │  ┌────────────────────────────────────────────────────────┐    │  │
│  │  │ GitHubActionsRole                                      │    │  │
│  │  │ ├─ Policies:                                           │    │  │
│  │  │ │  ├─ EKS (terraform-managed)                         │    │  │
│  │  │ │  ├─ EC2 (terraform-managed)                         │    │  │
│  │  │ │  ├─ IAM (terraform-managed)                         │    │  │
│  │  │ │  └─ S3 (custom: github-actions-s3-models-access)   │    │  │
│  │  │ ├─ Credentials: Temporary tokens (1 hour max)         │    │  │
│  │  │ └─ Audit Trail: CloudTrail logging                    │    │  │
│  │  └────────────────────────────────────────────────────────┘    │  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────┐    │  │
│  │  │ VPC                                                    │    │  │
│  │  │ ├─ CIDR: 10.0.0.0/16                                 │    │  │
│  │  │ ├─ Public Subnets (3): NAT Gateway, IGW              │    │  │
│  │  │ ├─ Private Subnets (3): EKS nodes, KServe pods       │    │  │
│  │  │ ├─ Security Groups: Traffic rules                     │    │  │
│  │  │ └─ Internet Gateway / NAT Gateway                     │    │  │
│  │  └────────────────────────────────────────────────────────┘    │  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────┐    │  │
│  │  │ EKS Cluster (ml-ops-cluster)                          │    │  │
│  │  │ ├─ Version: 1.30                                      │    │  │
│  │  │ ├─ Control Plane: Managed by AWS                     │    │  │
│  │  │ ├─ Worker Nodes: 2-3 m5.xlarge instances             │    │  │
│  │  │ ├─ IAM Role: eks-node-role                           │    │  │
│  │  │ │  └─ Policies:                                       │    │  │
│  │  │ │     ├─ AmazonEKSWorkerNodePolicy                   │    │  │
│  │  │ │     ├─ AmazonEKS_CNI_Policy                        │    │  │
│  │  │ │     └─ eks-s3-models-access (custom)               │    │  │
│  │  │ ├─ Add-ons: vpc-cni, coredns, kube-proxy             │    │  │
│  │  │ └─ aws-auth ConfigMap: IAM role → Kubernetes mapping │    │  │
│  │  └────────────────────────────────────────────────────────┘    │  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────┐    │  │
│  │  │ S3 Bucket (mlops-trainig-*-us-east-1-an)             │    │  │
│  │  │ ├─ Model Storage:                                      │    │  │
│  │  │ │  ├─ linear-regression/model.joblib                  │    │  │
│  │  │ │  ├─ models/*                                        │    │  │
│  │  │ │  └─ training-outputs/*                              │    │  │
│  │  │ ├─ Access Control:                                     │    │  │
│  │  │ │  ├─ EKS node role (ReadOnly)                       │    │  │
│  │  │ │  └─ GitHub Actions role (ReadWrite)                │    │  │
│  │  │ └─ Encryption: SSE-S3 default                         │    │  │
│  │  └────────────────────────────────────────────────────────┘    │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes (EKS Cluster)                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ kube-system (Core Services)                             │  │  │
│  │  │ ├─ aws-auth ConfigMap                                   │  │  │
│  │  │ │  ├─ mapRoles:                                         │  │  │
│  │  │ │  │  ├─ Node Role → system:nodes                      │  │  │
│  │  │ │  │  └─ GitHub Role → system:masters                  │  │  │
│  │  │ │  └─ RBAC Authorization                               │  │  │
│  │  │ ├─ coredns (DNS)                                        │  │  │
│  │  │ └─ kube-proxy (Service routing)                         │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ cert-manager (TLS Certificates)                         │  │  │
│  │  │ ├─ Manages HTTPS certificates                           │  │  │
│  │  │ ├─ Self-signed certs for internal services              │  │  │
│  │  │ └─ Helm Release: cert-manager                           │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ istio-system (Service Mesh & Ingress)                   │  │  │
│  │  │ ├─ istiod (Service mesh control plane)                 │  │  │
│  │  │ ├─ ingress-gateway (External traffic)                   │  │  │
│  │  │ ├─ Network policies and traffic management              │  │  │
│  │  │ └─ Helm Releases: istio-base, istiod                    │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ kserve (Model Serving)                                  │  │  │
│  │  │ ├─ InferenceService: sklearn-model                      │  │  │
│  │  │ │  ├─ Storage URI: s3://bucket/linear-regression/...   │  │  │
│  │  │ │  ├─ Model Format: sklearn                             │  │  │
│  │  │ │  ├─ Predictor Pods:                                   │  │  │
│  │  │ │  │  ├─ Model Manager Container                       │  │  │
│  │  │ │  │  │  └─ Downloads model from S3 using node role    │  │  │
│  │  │ │  │  ├─ SKLearn Predictor Container                   │  │  │
│  │  │ │  │  │  └─ Serves model predictions                   │  │  │
│  │  │ │  │  └─ IAM Role: eks-node-role (inherited)           │  │  │
│  │  │ │  ├─ Replicas: 1-3 (auto-scaling)                     │  │  │
│  │  │ │  └─ Service: Internal LoadBalancer                   │  │  │
│  │  │ └─ Helm Release: sklearn-model (custom chart)           │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ kubeflow (ML Training & Orchestration)                  │  │  │
│  │  │ ├─ Central Dashboard (optional)                         │  │  │
│  │  │ ├─ Training Jobs (PyTorchJob, TFJob, etc.)             │  │  │
│  │  │ └─ Helm Release: kubeflow                               │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │ Worker Nodes (EC2 Instances)                            │  │  │
│  │  │ ├─ Count: 2-3 (m5.xlarge)                              │  │  │
│  │  │ ├─ IAM Instance Profile: eks-node-role                  │  │  │
│  │  │ ├─ EC2 Instance Metadata Service (IMDSv2)              │  │  │
│  │  │ │  └─ Provides temporary credentials to pods           │  │  │
│  │  │ ├─ Security Groups: EKS node SG                         │  │  │
│  │  │ ├─ kubelet: Manages pod lifecycle                       │  │  │
│  │  │ └─ Pod Networking: AWS VPC CNI plugin                   │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🔐 Credential Flow Diagram

```
┌──────────────────────┐
│  GitHub Actions Job  │
│  (workflow.yml)      │
└──────────┬───────────┘
           │
           │ Request OIDC token
           ↓
┌──────────────────────────────────────┐
│  GitHub OIDC Provider                │
│  (token.actions.githubusercontent.com) │
│  - Verifies: repo, branch, ref        │
│  - Issues: Short-lived JWT token      │
└──────────┬───────────────────────────┘
           │ JWT Token (valid ~1 hour)
           ↓
┌────────────────────────────────────────────────┐
│  AWS Security Token Service (STS)              │
│  AssumeRoleWithWebIdentity                     │
│  - Input: GitHub JWT token                     │
│  - Validates: Trust relationship               │
│  - Output: Temporary AWS credentials           │
│          - AccessKeyId                         │
│          - SecretAccessKey                     │
│          - SessionToken                        │
└──────────┬─────────────────────────────────────┘
           │ Temporary Credentials (1 hour)
           ↓
┌────────────────────────────────────────────────┐
│  GitHubActionsRole (IAM Role)                  │
│  - Trust Relationship: GitHub OIDC             │
│  - Permissions:                                │
│    ├─ Terraform: EC2, EKS, IAM, VPC            │
│    ├─ S3: Read/Write to ml-models bucket       │
│    ├─ KST: Token generation                    │
│    └─ CloudTrail: Audit logging                │
└──────────┬─────────────────────────────────────┘
           │ AWS API Calls with SigV4 signature
           ↓
    ┌──────────────────────┐
    │   AWS Services       │
    ├──────────────────────┤
    │ - EKS (Cluster)      │
    │ - EC2 (Nodes)        │
    │ - IAM (Roles)        │
    │ - VPC (Networking)   │
    │ - S3 (Model Storage) │
    │ - CloudTrail (Logs)  │
    └──────────────────────┘
```

## 🎯 Authentication by Component

### GitHub Actions → AWS
```
GitHub Actions (OIDC)
  ↓
GitHub OIDC Token
  ↓
AWS STS (AssumeRoleWithWebIdentity)
  ↓
GitHubActionsRole (Temporary credentials)
  ↓
Terraform / kubectl / helm
  ↓
AWS APIs / Kubernetes API
```

### KServe Pod → S3
```
KServe Pod (on EKS node)
  ↓
EC2 Instance Metadata Service
  ↓
Node IAM Role (Temporary credentials)
  ↓
boto3 S3 Client
  ↓
S3 Bucket (Download model)
```

### kubectl / helm → EKS
```
GitHub Actions (with GitHubActionsRole)
  ↓
aws eks update-kubeconfig (AWS CLI)
  ↓
kubeconfig (signed by IAM credentials)
  ↓
KubeAPIServer (verifies IAM signature)
  ↓
aws-auth ConfigMap (maps IAM role → k8s user)
  ↓
RBAC Authorization (system:masters group)
  ↓
Kubernetes Resources (pods, services, etc.)
```

## 📦 Data Flow

### Model Preparation & Deployment
```
1. GitHub Actions triggered (git push)
   ↓
2. prepare_model.py runs
   ├─ Reads: model_artifacts/linear_regression_model.json
   ├─ Converts: JSON → sklearn pickle
   ├─ Saves: model_artifacts/model.joblib
   └─ Uploads: s3://bucket/linear-regression/model.joblib
   ↓
3. Helm chart deployed
   ├─ Template: helm/ml-model/templates/inference-service.yaml
   ├─ Values: helm/ml-model/values.yaml
   └─ Create: InferenceService resource
   ↓
4. KServe controller processes InferenceService
   ├─ Create: Model Manager pod
   ├─ Download: Model from S3 using node IAM role
   ├─ Create: Predictor pod (sklearn server)
   └─ Deploy: Both pods in kserve namespace
   ↓
5. Model becomes available for predictions
   ├─ Endpoint: http://sklearn-model.kserve.svc.cluster.local
   ├─ API: POST /v1/models/sklearn-model:predict
   └─ Response: JSON predictions
```

### Prediction Request Flow
```
Client
  ↓
HTTP POST to KServe endpoint
  ↓
Istio Ingress Gateway
  ↓
KServe Predictor Service
  ↓
SKLearn Model Server Pod
  ├─ Loads model from /mnt/models/model.joblib
  ├─ Processes input features
  ├─ Runs: model.predict(features)
  └─ Returns: predictions as JSON
  ↓
HTTP 200 Response with predictions
  ↓
Client (application)
```

## 🔑 Key Components Summary

| Component | Purpose | IAM Role Used |
|-----------|---------|---------------|
| GitHub Actions | CI/CD pipeline automation | GitHubActionsRole |
| Terraform | Infrastructure provisioning | GitHubActionsRole |
| kubectl | Kubernetes cluster access | GitHubActionsRole → aws-auth ConfigMap |
| helm | Application deployment | GitHubActionsRole |
| KServe Pods | Model serving | EKS node role (via IMDS) |
| S3 Bucket | Model storage | Node role (read) + GitHub role (write) |
| EKS Cluster | Kubernetes control plane | AWS managed |
| Worker Nodes | Pod execution | Node IAM instance profile |

## 🛡️ Security Layers

1. **Network Layer**
   - VPC isolation
   - Security groups
   - Network policies

2. **Identity Layer**
   - GitHub OIDC (federation)
   - IAM roles (temporary credentials)
   - STS tokens (short-lived)

3. **Authorization Layer**
   - IAM policies (AWS API access)
   - aws-auth ConfigMap (Kubernetes RBAC)
   - RBAC roles/bindings (Kubernetes resources)

4. **Audit Layer**
   - CloudTrail (AWS API calls)
   - Kubernetes audit logs (API server)
   - Container logs (application events)

5. **Encryption Layer**
   - TLS for all API communication
   - S3 encryption (default: SSE-S3)
   - Secrets management (AWS Secrets Manager)

## 📊 Deployment Timeline

```
Time  Phase              Components Ready
────  ─────────────────  ──────────────────────────────────────
0min  Triggered          GitHub Actions workflow starts
5min  AWS Setup          EKS cluster created, nodes launching
10min Infrastructure     VPC, IAM, networking ready
15min Kubernetes Up      EKS control plane + worker nodes ready
20min Add-ons Deployed   coredns, vpc-cni, kube-proxy active
25min Cert-Manager       TLS certificate management online
30min Istio              Service mesh and ingress operational
35min KServe             Inference service framework ready
40min Kubeflow           Training orchestration online
45min Model Prep         JSON model converted to sklearn
50min Model Upload       Model.joblib uploaded to S3
55min Helm Deploy        Custom Helm chart deployed
60min Model Serving      KServe pod downloading model from S3
65min Ready              Model fully loaded, accepting predictions

Total: ~65 minutes for full deployment
```

## ✅ Verification Points

At each stage, verify:
- GitHub Actions workflow status (green checkmarks)
- AWS Terraform apply completed
- EKS cluster ACTIVE status
- Worker nodes Ready
- Kubernetes namespaces created
- Helm releases deployed
- KServe InferenceService Ready
- Model pods Running
- S3 model accessible

This architecture provides **production-grade security, scalability, and observability**! 🚀
