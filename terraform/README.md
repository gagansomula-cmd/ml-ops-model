# Terraform EKS with Kubeflow and KServe Deployment

This Terraform configuration provisions a complete ML Ops infrastructure on AWS EKS with Kubeflow and KServe.

## Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (2)
│   ├── NAT Gateway
│   └── Internet Gateway
├── Private Subnets (2)
│   └── EKS Nodes
└── EKS Cluster
    ├── Kubeflow (ML Pipelines, Notebooks, Katib)
    ├── KServe (Model Serving)
    ├── Cert-Manager (Certificate Management)
    └── Add-ons (VPC-CNI, CoreDNS, KubeProxy)
```

## Prerequisites

1. **AWS Account**: With appropriate IAM permissions
2. **AWS CLI**: `aws --version`
3. **Terraform**: `terraform --version` (>= 1.0)
4. **kubectl**: `kubectl version --client`
5. **Helm**: `helm version`

### Install Required Tools

```bash
# macOS
brew install awscli terraform kubectl helm

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Setup

### 1. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter default output format (json)
```

### 2. Clone and Navigate to Terraform Directory

```bash
cd ml-ops/ml-ops-model/terraform
```

### 3. Customize Configuration

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your preferences
nano terraform.tfvars
```

Key variables to customize:
- `aws_region`: AWS region for deployment
- `cluster_name`: EKS cluster name
- `node_instance_type`: EC2 instance type (m5.xlarge, m5.2xlarge, etc.)
- `node_group_desired_size`: Number of worker nodes
- `enable_kubeflow`: Set to `true` to deploy Kubeflow
- `enable_kserve`: Set to `true` to deploy KServe

### 4. Update Helm Values (Optional)

Edit the Helm values files to customize Kubeflow and KServe:

```bash
# Edit Kubeflow values
nano helm-values/kubeflow-values.yaml

# Edit KServe values
nano helm-values/kserve-values.yaml
```

## Deployment

### 1. Initialize Terraform

```bash
terraform init
```

This downloads the required provider plugins.

### 2. Review Planned Changes

```bash
terraform plan -out=tfplan
```

Review the output to ensure all changes are expected.

### 3. Apply Configuration

```bash
terraform apply tfplan
```

**Estimated Time**: 15-20 minutes

### 4. Configure kubectl

After deployment, configure kubectl to access your cluster:

```bash
# Get the command from Terraform output
aws eks update-kubeconfig --region us-east-1 --name ml-ops-cluster

# Verify cluster access
kubectl get nodes
```

### 5. Verify Deployments

```bash
# Check Kubeflow namespace
kubectl get pods -n kubeflow

# Check KServe namespace
kubectl get pods -n kserve

# Check cert-manager
kubectl get pods -n cert-manager

# Monitor deployment progress
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

## Access Kubeflow UI

### Option 1: Port Forwarding

```bash
kubectl port-forward -n kubeflow svc/central-dashboard 8080:80
```

Then navigate to: `http://localhost:8080`

### Option 2: Configure Ingress

Update `helm-values/kubeflow-values.yaml` with your domain and install an ingress controller:

```bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm install nginx-ingress nginx-stable/nginx-ingress \
  -n ingress-nginx --create-namespace
```

## Deploy a Model with KServe

### 1. Create S3 Bucket for Models

```bash
BUCKET_NAME="ml-ops-models-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Upload your model
aws s3 cp linear_regression_model.json s3://$BUCKET_NAME/
```

### 2. Create InferenceService

Create `inference-service.yaml`:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: linear-regression
  namespace: kserve
spec:
  predictor:
    sklearn:
      storageUri: s3://ml-ops-models-xxx/linear_regression_model.json
      resources:
        requests:
          cpu: "500m"
          memory: "512Mi"
        limits:
          cpu: "1"
          memory: "1Gi"
```

Deploy the model:

```bash
kubectl apply -f inference-service.yaml

# Monitor deployment
kubectl get inferenceservice -n kserve -w

# Check service status
kubectl get svc -n kserve
```

### 3. Make Predictions

```bash
# Port forward the KServe service
kubectl port-forward -n kserve svc/linear-regression 8080:80

# Make a prediction request
curl -X POST http://localhost:8080/v1/models/linear-regression:predict \
  -H "Content-Type: application/json" \
  -d '{"instances": [[1.0, 2.0, 3.0]]}'
```

## Monitoring and Logging

### View Cluster Logs

```bash
# View control plane logs
aws logs tail /aws/eks/ml-ops-cluster/cluster

# View node logs
kubectl logs -n kube-system -l component=kubelet
```

### Monitor Resource Usage

```bash
# Install metrics-server (if not installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# View node metrics
kubectl top nodes

# View pod metrics
kubectl top pods -n kubeflow
kubectl top pods -n kserve
```

### Optional: Install Prometheus and Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default credentials: admin / prom-operator
```

## Cleanup

To destroy all resources:

```bash
terraform destroy

# Confirm by typing 'yes'
```

**Important**: This will delete:
- EKS cluster
- EC2 instances (worker nodes)
- VPC and associated resources
- Load Balancers and EBS volumes
- All Kubeflow and KServe deployments

## Troubleshooting

### Pod stuck in Pending state

```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check resource availability
kubectl top nodes
kubectl describe nodes

# Check if nodes are ready
kubectl get nodes
```

### EKS cluster creation failed

Check IAM permissions and service quota:

```bash
# List IAM policies
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query User.Arn --output text | cut -d/ -f2)

# Check service quota
aws service-quotas list-service-quotas --service-code ec2
```

### Kubeflow/KServe not deploying

```bash
# Check Helm release status
helm status kubeflow -n kubeflow
helm status kserve -n kserve

# Check Helm events
kubectl describe helmrelease -n kubeflow

# Get detailed logs
kubectl logs -n kubeflow -l app=kubeflow-controller-manager
kubectl logs -n kserve -l control-plane=kserve-controller-manager
```

### Model inference not working

```bash
# Check InferenceService status
kubectl describe inferenceservice <model-name> -n kserve

# Check predictor pod logs
kubectl logs -n kserve -l component=predictor

# Verify S3 access
kubectl exec -it <pod-name> -n kserve -- aws s3 ls s3://your-bucket
```

## Cost Optimization

### 1. Use Spot Instances (Production)

Add to `eks.tf` in the node group:

```hcl
capacity_type = "SPOT"
```

### 2. Enable Cluster Autoscaler

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install autoscaler autoscaler/cluster-autoscaler \
  -n kube-system \
  --set autoDiscovery.clusterName=ml-ops-cluster \
  --set awsRegion=us-east-1
```

### 3. Right-size Node Groups

Adjust `node_instance_type` and `node_group_desired_size` in `terraform.tfvars`.

## Security Best Practices

1. **Enable VPC Flow Logs**:
   ```bash
   aws ec2 create-flow-logs --resource-type VPC --resource-ids <vpc-id> \
     --traffic-type ALL --log-destination-type cloud-watch-logs \
     --log-group-name /aws/vpc/flowlogs
   ```

2. **Enable EKS Control Plane Logging**:
   ```hcl
   # Add to eks.tf
   enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
   ```

3. **Network Policies**: Uncomment `networkPolicy.enabled = true` in Helm values.

4. **Pod Security Standards**: Use Pod Security Standards (PSS) instead of deprecated PSP.

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [KServe Documentation](https://kserve.github.io/website/)
- [Helm Documentation](https://helm.sh/docs/)

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review AWS EKS documentation
3. Check Kubeflow and KServe GitHub issues
4. Review Terraform AWS provider documentation
