terraform {
  required_version = ">= 1.6"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
  }
}
provider "aws" { region = "ap-northeast-2"
profile = var.aws_profile }
data "terraform_remote_state" "infra" { backend = "local"
config = { path = "../terraform.tfstate" } }
data "aws_eks_cluster_auth" "main" { name = data.terraform_remote_state.infra.outputs.eks_cluster_name }
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca)
  token                  = data.aws_eks_cluster_auth.main.token
}
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
