terraform {

  required_version = ">= 1.7.0"
  required_providers {

    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes", version = "~> 2.36"
    }
    helm = {
      source = "hashicorp/helm", version = "~> 3.0"
    }
    tls = {
      source = "hashicorp/tls", version = "~> 4.0"
    }

  }

}

provider "aws" {
  region  = local.input.region
  profile = local.input.aws_profile
  default_tags {
    tags = merge(local.input.tags, {
      Project   = "wsc2026"
      TaskId    = local.input.task_id
      ManagedBy = "Terraform"
    })
  }
}
data "aws_eks_cluster" "main" {
  name = local.input.cluster_name
}
data "aws_eks_cluster_auth" "main" {
  name = local.input.cluster_name
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}


locals {
  ingress_tags = merge({
    Project   = "wsc2026"
    TaskId    = local.input.task_id
    ManagedBy = "Terraform"
  }, local.input.tags)
}

data "aws_caller_identity" "current" {

}
data "aws_partition" "current" {

}
data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}
resource "aws_eks_pod_identity_association" "book" {
  cluster_name    = local.input.cluster_name
  namespace       = kubernetes_namespace_v1.book.metadata[0].name
  service_account = kubernetes_service_account_v1.book.metadata[0].name
  role_arn        = local.input.book_pod_role_arn
}

resource "aws_iam_openid_connect_provider" "eks" {

  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

}
data "aws_iam_policy_document" "lbc_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
