#!/bin/bash
# Quick start script for deploying EKS with Kubeflow and KServe

set -e

echo "=========================================="
echo "ML-Ops EKS with Kubeflow & KServe Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
    fi
}

check_command "aws"
check_command "terraform"
check_command "kubectl"
check_command "helm"

# Verify AWS credentials
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo "  Account: $AWS_ACCOUNT"
echo "  Region: $AWS_REGION"
echo ""

# Setup Terraform variables
echo -e "${YELLOW}[2/5] Setting up Terraform variables...${NC}"

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from template...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    
    # Update account ID in Helm values (if needed)
    sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT/g" terraform.tfvars
    rm -f terraform.tfvars.bak
    
    echo -e "${GREEN}✓ terraform.tfvars created${NC}"
    echo "  Please review and edit terraform.tfvars if needed"
else
    echo -e "${GREEN}✓ terraform.tfvars already exists${NC}"
fi
echo ""

# Initialize Terraform
echo -e "${YELLOW}[3/5] Initializing Terraform...${NC}"
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Plan and review
echo -e "${YELLOW}[4/5] Planning Terraform deployment...${NC}"
terraform plan -out=tfplan
echo -e "${GREEN}✓ Plan created (tfplan)${NC}"
echo ""

# Apply changes
echo -e "${YELLOW}[5/5] Applying Terraform configuration...${NC}"
read -p "Do you want to apply these changes? (yes/no): " -r
echo
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    terraform apply tfplan
    echo -e "${GREEN}✓ Infrastructure deployed successfully!${NC}"
else
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi
echo ""

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl...${NC}"
CLUSTER_NAME=$(terraform output -raw cluster_id)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
echo -e "${GREEN}✓ kubectl configured${NC}"
echo ""

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready node --all --timeout=5m || true
echo -e "${GREEN}✓ Cluster nodes ready${NC}"
echo ""

# Display deployment summary
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "Cluster Information:"
CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
echo "  Name: $CLUSTER_NAME"
echo "  Endpoint: $CLUSTER_ENDPOINT"
echo "  Region: $AWS_REGION"
echo ""

echo "Next Steps:"
echo ""
echo "1. Monitor deployment progress:"
echo "   kubectl get pods -n kubeflow"
echo "   kubectl get pods -n kserve"
echo ""

echo "2. Access Kubeflow UI (port forwarding):"
echo "   kubectl port-forward -n kubeflow svc/central-dashboard 8080:80"
echo "   Then open: http://localhost:8080"
echo ""

echo "3. Deploy a model:"
echo "   kubectl apply -f inference-service.yaml"
echo ""

echo "4. View logs:"
echo "   kubectl logs -n kubeflow -l app=kubeflow-controller"
echo "   kubectl logs -n kserve -l control-plane=kserve-controller-manager"
echo ""

echo "5. Cleanup (delete all resources):"
echo "   terraform destroy"
echo ""

echo -e "${GREEN}For more details, see README.md${NC}"
