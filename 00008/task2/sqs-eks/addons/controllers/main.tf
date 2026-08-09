terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
  }
}
provider "aws" { region = "us-west-2" }
data "terraform_remote_state" "infra" {
  backend = "local"
  config  = { path = "../../infra/terraform.tfstate" }
}
data "aws_eks_cluster" "this" { name = data.terraform_remote_state.infra.outputs.cluster_name }
data "aws_eks_cluster_auth" "this" { name = data.aws_eks_cluster.this.name }
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
resource "kubernetes_namespace_v1" "keda" { metadata { name = "keda" } }
resource "kubernetes_namespace_v1" "karpenter" { metadata { name = "karpenter" } }
resource "kubernetes_annotations" "coredns" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  annotations = { "eks.amazonaws.com/compute-type" = "fargate" }
  force       = true
}
resource "helm_release" "keda" {
  name       = "keda"
  namespace  = kubernetes_namespace_v1.keda.metadata[0].name
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_chart_version
  values = [yamlencode({
    serviceAccount = {
      operator = {
        create = true
        name   = "keda-operator"
        annotations = { "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infra.outputs.keda_role_arn }
      }
    }
    podLabels = { "eks.amazonaws.com/compute-type" = "fargate" }
  })]
}
resource "helm_release" "karpenter" {
  name                = "karpenter"
  namespace           = kubernetes_namespace_v1.karpenter.metadata[0].name
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = var.karpenter_chart_version
  repository_username = "AWS"
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  values = [yamlencode({
    serviceAccount = {
      create      = true
      name        = "karpenter"
      annotations = { "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infra.outputs.karpenter_role_arn }
    }
    settings = { clusterName = data.aws_eks_cluster.this.name }
    controller = { resources = { requests = { cpu = "250m", memory = "256Mi" }, limits = { cpu = "1", memory = "1Gi" } } }
  })]
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.use1
}
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
variable "keda_chart_version" {
  type    = string
  default = "2.17.2"
}
variable "karpenter_chart_version" {
  type    = string
  default = "1.6.3"
}
