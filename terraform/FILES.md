# Terraform Files Structure

This directory contains a complete Terraform configuration for deploying an EKS cluster with Kubeflow and KServe on AWS.

## File Structure

```
terraform/
├── provider.tf                    # AWS, Kubernetes, and Helm providers
├── variables.tf                   # Input variables (configurable)
├── vpc.tf                        # VPC, subnets, security groups, NAT
├── eks.tf                        # EKS cluster, node groups, addons
├── helm.tf                       # Kubeflow, KServe, cert-manager deployments
├── outputs.tf                    # Output values (cluster info, endpoints)
├── terraform.tfvars.example      # Example variable values
├── terraform.tfvars              # ACTUAL variable values (create from example)
├── quick-start.sh                # Automated setup script
├── README.md                     # Comprehensive documentation
├── example-inference-service.yaml # Example KServe model deployment
├── helm-values/
│   ├── kubeflow-values.yaml      # Kubeflow Helm chart values
│   └── kserve-values.yaml        # KServe Helm chart values
└── .terraform/                   # Terraform working directory (auto-created)
```

## File Descriptions

### Core Terraform Files

#### `provider.tf`
Configures the AWS, Kubernetes, and Helm providers. Authenticates with AWS and the EKS cluster.

**Key Components:**
- AWS provider configuration
- Kubernetes provider using EKS cluster credentials
- Helm provider for installing charts
- Data sources for cluster authentication

#### `variables.tf`
Defines all input variables with defaults and descriptions. Allows customization without editing other files.

**Key Variables:**
- AWS region and EKS cluster settings
- VPC CIDR and networking configuration
- Node group sizing and instance types
- Kubeflow and KServe feature flags
- Component versions
- Environment tags

#### `vpc.tf`
Creates the AWS VPC infrastructure with networking, NAT gateways, and security groups.

**Creates:**
- VPC with custom CIDR block
- 2 public subnets (for load balancers)
- 2 private subnets (for EKS nodes)
- Internet Gateway and NAT Gateways
- Route tables (public and private)
- Security groups (cluster and nodes)

**Network Layout:**
- Public subnets: 10.0.101.0/24 and 10.0.102.0/24
- Private subnets: 10.0.1.0/24 and 10.0.2.0/24

#### `eks.tf`
Provisions the EKS cluster with nodes and add-ons.

**Creates:**
- IAM roles and policies for cluster and nodes
- EKS cluster with specified version
- EC2 node group with auto-scaling
- EKS add-ons (VPC-CNI, CoreDNS, KubeProxy)
- OIDC provider for IRSA (IAM Roles for Service Accounts)

**Features:**
- VPC CNI for advanced networking
- CoreDNS for service discovery
- KubeProxy for load balancing

#### `helm.tf`
Deploys Kubeflow and KServe using Helm charts with IAM integration.

**Deploys:**
1. **cert-manager** - Certificate management for HTTPS
2. **Kubeflow** - ML pipeline orchestration and notebook environments
3. **KServe** - Model serving and inference
4. **IAM Roles** - Service account integration with AWS services

**IRSA Configuration:**
- Service accounts with AWS IAM role annotations
- S3 access for model artifacts
- Automatic credential management

#### `outputs.tf`
Exports important values from the Terraform state.

**Outputs:**
- EKS cluster ID, ARN, endpoint
- VPC and subnet IDs
- Kubeflow and KServe deployment information
- kubectl configuration command
- IAM role ARNs for service accounts

### Configuration Files

#### `terraform.tfvars.example`
Template for variable values. Copy to `terraform.tfvars` and customize.

**Important Settings:**
- `aws_region`: Where to deploy
- `cluster_name`: EKS cluster name
- `node_instance_type`: EC2 instance type
- `enable_kubeflow` and `enable_kserve`: Feature flags

#### `terraform.tfvars`
Actual variable file (created from example). Do not commit to version control.

**Action Required:**
1. Copy from .example: `cp terraform.tfvars.example terraform.tfvars`
2. Edit with your desired values
3. Add to .gitignore if using version control

### Helm Values

#### `helm-values/kubeflow-values.yaml`
Configuration for Kubeflow Helm chart.

**Components:**
- Central Dashboard (ML UI)
- Jupyter Web App (notebook environments)
- Katib (hyperparameter tuning)
- Kubeflow Pipelines (ML workflow orchestration)
- Training Operators (PyTorch, TensorFlow)
- ML Metadata server

**Customizable:**
- Replica counts
- Resource requests/limits
- Storage configuration
- Ingress settings
- Service account annotations

#### `helm-values/kserve-values.yaml`
Configuration for KServe Helm chart.

**Components:**
- KServe Controller
- Model server runtimes (sklearn, XGBoost, PyTorch, TensorFlow, ONNX, Triton)
- Storage configuration
- Autoscaling policies

**Features:**
- S3 integration for model storage
- Canary deployments (A/B testing)
- Autoscaling with custom metrics
- Security contexts

### Documentation and Scripts

#### `README.md`
Comprehensive guide covering:
- Architecture overview
- Prerequisites and installation
- Step-by-step deployment instructions
- Accessing Kubeflow and KServe
- Model deployment examples
- Monitoring and logging
- Troubleshooting
- Cost optimization
- Security best practices

#### `quick-start.sh`
Automated deployment script that:
1. Checks prerequisites (AWS CLI, Terraform, kubectl, Helm)
2. Verifies AWS credentials
3. Creates terraform.tfvars
4. Initializes Terraform
5. Plans and applies configuration
6. Configures kubectl
7. Displays next steps

**Usage:**
```bash
chmod +x quick-start.sh
./quick-start.sh
```

#### `example-inference-service.yaml`
Example Kubernetes manifests for deploying ML models with KServe.

**Includes:**
- Basic InferenceService for sklearn model
- Transformer example (preprocessing)
- Explainer configuration (model interpretability)
- HorizontalPodAutoscaler (auto-scaling)
- NetworkPolicy (security)
- PodDisruptionBudget (high availability)
- LoadBalancer Service

### Auto-Generated Directories

#### `.terraform/`
Terraform working directory. Created by `terraform init`.
Contains:
- Provider plugins
- Module cache
- Backend configuration

**Action:** Add to .gitignore

#### `terraform.tfstate` and `terraform.tfstate.backup`
Terraform state files tracking current infrastructure.

**Important:** 
- Do not edit manually
- Keep secure (never commit to version control)
- Consider using remote state for teams (S3, Terraform Cloud)
- Add to .gitignore

## Deployment Workflow

### 1. Initialization Phase
- User customizes `terraform.tfvars`
- `terraform init` downloads providers
- Terraform prepares execution plan

### 2. VPC Creation (vpc.tf)
- Creates VPC and subnets
- Sets up NAT gateways and internet gateway
- Configures security groups and route tables

### 3. EKS Cluster Creation (eks.tf)
- Creates IAM roles for cluster and nodes
- Provisions EKS cluster
- Launches EC2 node group
- Installs cluster add-ons

### 4. Helm Deployments (helm.tf)
- Installs cert-manager for certificates
- Deploys Kubeflow and components
- Deploys KServe and runtimes
- Creates IRSA for AWS service integration

### 5. Post-Deployment
- kubectl is configured automatically
- Services become accessible
- Models can be deployed

## Security Considerations

1. **IAM Roles**: Uses temporary credentials via IRSA, no long-lived keys
2. **Network**: Private subnets for nodes, public only for load balancers
3. **RBAC**: Kubernetes RBAC enabled by default
4. **Encryption**: EBS volumes encrypted by default
5. **Pod Security**: Can be enabled via network policies

## Cost Optimization

- **Spot Instances**: Uncomment in eks.tf for 70% cost savings
- **Cluster Autoscaler**: Scale nodes based on demand
- **Resource Limits**: Properly configure pod resource requests
- **Instance Types**: Choose right-sized instances (m5.xlarge as default)

## Variables and Outputs

### Key Variables
- `cluster_name`: Identifier for all resources
- `aws_region`: Deployment location
- `node_instance_type`: Compute resource size
- `enable_kubeflow`, `enable_kserve`: Feature toggles

### Key Outputs
- `cluster_endpoint`: API server address
- `configure_kubectl`: Command to setup local access
- `kubeflow_role_arn`, `kserve_role_arn`: For service account configuration

## Next Steps

1. **Setup**: Run `./quick-start.sh` or follow README.md
2. **Customize**: Edit `terraform.tfvars` for your environment
3. **Deploy**: Run `terraform apply`
4. **Access**: Use port forwarding or configure ingress
5. **Deploy Models**: Use `example-inference-service.yaml` as template
6. **Monitor**: Check pod status and logs
7. **Cleanup**: Run `terraform destroy` when done

## Support and Troubleshooting

- See README.md for detailed troubleshooting
- Check AWS CloudFormation events if cluster creation fails
- Use `kubectl describe` and `kubectl logs` for pod issues
- Review Helm release status with `helm status`
