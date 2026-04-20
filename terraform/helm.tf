resource "kubernetes_namespace" "kubeflow" {
  count = var.enable_kubeflow ? 1 : 0

  metadata {
    name = "kubeflow"

    labels = {
      "app.kubernetes.io/name" = "kubeflow"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "kubernetes_namespace" "kserve" {
  count = var.enable_kserve ? 1 : 0

  metadata {
    name = "kserve"

    labels = {
      "app.kubernetes.io/name" = "kserve"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "kubernetes_namespace" "cert_manager" {
  count = var.enable_kserve ? 1 : 0

  metadata {
    name = "cert-manager"

    labels = {
      "app.kubernetes.io/name" = "cert-manager"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# Install cert-manager (required for KServe)
resource "helm_release" "cert_manager" {
  count = var.enable_kserve ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert_manager[0].metadata[0].name
  create_namespace = false
  version          = "v1.13.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# Install Kubeflow
resource "helm_release" "kubeflow" {
  count = var.enable_kubeflow ? 1 : 0

  name             = "kubeflow"
  repository       = "https://charts.kubeflow.org"
  chart            = "kubeflow"
  namespace        = kubernetes_namespace.kubeflow[0].metadata[0].name
  create_namespace = false
  version          = var.kubeflow_version

  values = [
    templatefile("${path.module}/helm-values/kubeflow-values.yaml", {
      cluster_name = var.cluster_name
    })
  ]

  timeout = 900

  depends_on = [kubernetes_namespace.kubeflow, aws_eks_node_group.main]
}

# Install KServe
resource "helm_release" "kserve" {
  count = var.enable_kserve ? 1 : 0

  name             = "kserve"
  repository       = "https://kserve.github.io/charts"
  chart            = "kserve"
  namespace        = kubernetes_namespace.kserve[0].metadata[0].name
  create_namespace = false
  version          = var.kserve_version

  values = [
    templatefile("${path.module}/helm-values/kserve-values.yaml", {
      cluster_name = var.cluster_name
    })
  ]

  timeout = 600

  depends_on = [
    kubernetes_namespace.kserve,
    helm_release.cert_manager,
    aws_eks_node_group.main
  ]
}

# Install Kubeflow KServe plugin (optional, for integration)
resource "helm_release" "kubeflow_kserve" {
  count = var.enable_kubeflow && var.enable_kserve ? 1 : 0

  name             = "kubeflow-kserve"
  repository       = "https://charts.kubeflow.org"
  chart            = "kubeflow-kserve"
  namespace        = kubernetes_namespace.kubeflow[0].metadata[0].name
  create_namespace = false
  version          = var.kubeflow_version

  timeout = 300

  depends_on = [
    helm_release.kubeflow,
    helm_release.kserve
  ]
}

# Create OIDC provider for IRSA (IAM Roles for Service Accounts)
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# IAM role for Kubeflow service account (for S3 access, etc.)
resource "aws_iam_role" "kubeflow_sa" {
  count = var.enable_kubeflow ? 1 : 0

  name_prefix = "${var.cluster_name}-kubeflow-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kubeflow:kubeflow-sa"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "kubeflow_s3" {
  count = var.enable_kubeflow ? 1 : 0

  name_prefix = "${var.cluster_name}-kubeflow-s3-"
  role        = aws_iam_role.kubeflow_sa[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for KServe service account
resource "aws_iam_role" "kserve_sa" {
  count = var.enable_kserve ? 1 : 0

  name_prefix = "${var.cluster_name}-kserve-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kserve:kserve-sa"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "kserve_s3" {
  count = var.enable_kserve ? 1 : 0

  name_prefix = "${var.cluster_name}-kserve-s3-"
  role        = aws_iam_role.kserve_sa[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}
