# 📚 Documentation Index - ML-Ops IAM Role-Based Authentication

Welcome! This project implements a complete ML-Ops pipeline on AWS EKS with enterprise-grade security using IAM role-based authentication instead of hardcoded credentials.

## 📖 Documentation Structure

### 🚀 Getting Started
Start here if you're new to this project:

1. **[COMPLETE_UPDATE_SUMMARY.md](COMPLETE_UPDATE_SUMMARY.md)** ⭐ START HERE
   - What's been updated in this project
   - Overview of all changes
   - Files modified
   - Next steps

2. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Operational Handbook
   - Quick start commands
   - Common operations
   - Daily checklists
   - Troubleshooting commands
   - Configuration file locations

### 🏗️ Understanding the Architecture

3. **[ARCHITECTURE.md](ARCHITECTURE.md)** - System Design
   - Complete system diagram
   - Credential flow diagrams
   - Authentication by component
   - Data flow visualization
   - Deployment timeline
   - Component summary table
   - Security layers

4. **[IAM_ROLES.md](IAM_ROLES.md)** - Authentication Deep Dive
   - GitHub OIDC setup
   - All 3 IAM roles explained
   - aws-auth ConfigMap mapping
   - Credential flow by component
   - Security best practices
   - Verification commands
   - Troubleshooting guide

### ✅ Deployment & Verification

5. **[DEPLOYMENT_VERIFICATION.md](DEPLOYMENT_VERIFICATION.md)** - Checklist & Testing
   - Pre-deployment checks
   - Post-deployment verification
   - Security verification
   - Model preparation tests
   - Kubernetes verification
   - Troubleshooting steps
   - Final success criteria

### 📁 Configuration Files

6. **[README.md](README.md)** - Project Overview
   - Project description
   - Features
   - Prerequisites
   - Quick start

## 🎯 Common Use Cases

### I'm deploying for the first time
```
1. Read: COMPLETE_UPDATE_SUMMARY.md (overview)
2. Read: ARCHITECTURE.md (understand design)
3. Run: Commands in QUICK_REFERENCE.md (Quick Start)
4. Follow: DEPLOYMENT_VERIFICATION.md (verify each step)
```

### I need to understand the authentication flow
```
1. Read: IAM_ROLES.md (complete explanation)
2. Review: ARCHITECTURE.md (diagrams)
3. Run: Verification commands in QUICK_REFERENCE.md
```

### I need to operate the system day-to-day
```
1. Use: QUICK_REFERENCE.md (daily operations)
2. Use: QUICK_REFERENCE.md checklists (morning/weekly)
3. Reference: DEPLOYMENT_VERIFICATION.md (troubleshooting)
```

### I'm having issues
```
1. Check: QUICK_REFERENCE.md (common issues section)
2. Check: DEPLOYMENT_VERIFICATION.md (troubleshooting)
3. Check: IAM_ROLES.md (authentication troubleshooting)
4. Review: ARCHITECTURE.md (verify design understanding)
```

### I'm updating the infrastructure
```
1. Reference: QUICK_REFERENCE.md (update workflows)
2. Reference: terraform/ (infrastructure code)
3. Verify: DEPLOYMENT_VERIFICATION.md (post-update checks)
```

### I'm deploying a new model
```
1. Use: QUICK_REFERENCE.md (update model code)
2. Reference: prepare_model.py (model preparation)
3. Verify: DEPLOYMENT_VERIFICATION.md (model verification)
```

## 🔐 Security Focus

All documentation emphasizes:
- ✅ Zero hardcoded credentials
- ✅ GitHub OIDC federation
- ✅ IAM role-based access
- ✅ Temporary credentials only
- ✅ Audit trail via CloudTrail
- ✅ RBAC authorization

## 📊 File Organization

```
ml-ops-model/
│
├── 📚 Documentation (Read First!)
│   ├── COMPLETE_UPDATE_SUMMARY.md ⭐ START HERE
│   ├── QUICK_REFERENCE.md (Operational handbook)
│   ├── ARCHITECTURE.md (System design)
│   ├── IAM_ROLES.md (Authentication guide)
│   ├── DEPLOYMENT_VERIFICATION.md (Checklist)
│   └── README.md (Project overview)
│
├── 🔧 Infrastructure (Terraform)
│   ├── terraform/github-oidc.tf (GitHub OIDC)
│   ├── terraform/eks.tf (EKS cluster)
│   ├── terraform/s3-models.tf (S3 bucket & IAM)
│   └── terraform/ (Other infrastructure)
│
├── 🚀 CI/CD (GitHub Actions)
│   └── .github/workflows/terraform.yml
│
├── ⚙️ Helm Charts
│   └── helm/ml-model/
│       ├── Chart.yaml
│       └── values.yaml
│
├── 🐍 Python Scripts
│   ├── prepare_model.py (Model preparation)
│   └── train_model.py (Model training)
│
└── 📦 Data & Artifacts
    ├── mlflow/ (ML experiment tracking)
    ├── model_artifacts/ (Trained models)
    └── mlruns/ (MLflow runs)
```

## 🚀 Deployment Flow

```
1. Read COMPLETE_UPDATE_SUMMARY.md
   └─→ Understand what's been done

2. Read ARCHITECTURE.md
   └─→ Understand the system design

3. Follow QUICK_REFERENCE.md (Quick Start)
   └─→ Initial deployment steps

4. Follow DEPLOYMENT_VERIFICATION.md
   └─→ Verify each step works

5. Use QUICK_REFERENCE.md
   └─→ Daily operations and monitoring

6. Refer to IAM_ROLES.md
   └─→ Troubleshooting authentication issues
```

## 📋 Documentation Features

### Quick Reference
- Command snippets ready to copy/paste
- Organized by task
- Common operations listed
- Troubleshooting sections

### Architecture Documentation
- System diagrams (text-based)
- Data flow visualizations
- Component descriptions
- Security layers explained

### Verification Checklists
- Pre-deployment checks
- Post-deployment verification
- Security checks
- Test procedures
- Success criteria

### Troubleshooting Guides
- Common issues and solutions
- Step-by-step diagnostics
- How to check logs
- How to verify components

## 🎓 Key Concepts

### GitHub OIDC
Federation protocol allowing GitHub Actions to request temporary AWS credentials without storing secrets.

### IAM Roles
AWS identity objects that define permissions. Each component (GitHub Actions, EKS nodes) gets its own role with minimal required permissions.

### aws-auth ConfigMap
Kubernetes ConfigMap that maps IAM roles to Kubernetes users and groups, enabling RBAC authorization.

### Temporary Credentials
AWS STS tokens that auto-expire (default 1 hour), eliminating long-lived key management.

### Least Privilege
Each component gets only the minimum permissions needed (principle of least privilege).

## ✅ Status

- ✅ All infrastructure files updated
- ✅ All GitHub Actions workflows updated
- ✅ All Python scripts updated
- ✅ All Helm charts updated
- ✅ All documentation completed
- ✅ Ready for production deployment

## 🆘 Need Help?

1. **First time?** → Read [COMPLETE_UPDATE_SUMMARY.md](COMPLETE_UPDATE_SUMMARY.md)
2. **Understanding design?** → Read [ARCHITECTURE.md](ARCHITECTURE.md)
3. **Daily operations?** → Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
4. **Troubleshooting?** → Check [DEPLOYMENT_VERIFICATION.md](DEPLOYMENT_VERIFICATION.md)
5. **Auth issues?** → Check [IAM_ROLES.md](IAM_ROLES.md)

## 📞 Quick Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

## 🏆 Project Features

✅ GitHub OIDC federation (no hardcoded keys)
✅ IAM role-based authentication (temporary credentials)
✅ EKS cluster with auto-scaling (2-3 nodes)
✅ KServe for ML model serving
✅ Helm charts for deployment automation
✅ S3 bucket for model storage
✅ CloudTrail audit logging
✅ aws-auth ConfigMap for RBAC
✅ Complete documentation

---

**Last Updated**: April 21, 2026
**Status**: ✅ Production Ready
**Security Level**: ⭐⭐⭐⭐⭐ Enterprise Grade

**Start with**: [COMPLETE_UPDATE_SUMMARY.md](COMPLETE_UPDATE_SUMMARY.md) ⭐
