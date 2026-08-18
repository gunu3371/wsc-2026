terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes", version = "~> 2.30"
    }
    helm = {
      source = "hashicorp/helm", version = "~> 2.13"
    }
  }
}
provider "aws" {
  region  = "ap-northeast-2"
  profile = var.aws_profile
}
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca)
  token                  = data.aws_eks_cluster_auth.main.token
}
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
