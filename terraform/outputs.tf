output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_certificate_authority" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = aws_iam_role.node.arn
}

output "kubeflow_namespace" {
  description = "Kubeflow namespace"
  value       = var.enable_kubeflow ? kubernetes_namespace.kubeflow[0].metadata[0].name : null
}

output "kserve_namespace" {
  description = "KServe namespace"
  value       = var.enable_kserve ? kubernetes_namespace.kserve[0].metadata[0].name : null
}

output "kubeflow_helm_release" {
  description = "Kubeflow Helm release name"
  value       = var.enable_kubeflow ? helm_release.kubeflow[0].name : null
}

output "kserve_helm_release" {
  description = "KServe Helm release name"
  value       = var.enable_kserve ? helm_release.kserve[0].name : null
}

output "kubeflow_role_arn" {
  description = "IAM role ARN for Kubeflow service account"
  value       = var.enable_kubeflow ? aws_iam_role.kubeflow_sa[0].arn : null
}

output "kserve_role_arn" {
  description = "IAM role ARN for KServe service account"
  value       = var.enable_kserve ? aws_iam_role.kserve_sa[0].arn : null
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.id}"
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}
