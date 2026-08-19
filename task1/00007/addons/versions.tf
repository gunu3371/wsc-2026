terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    archive    = { source = "hashicorp/archive", version = "~> 2.7" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.36" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = local.input.cluster_endpoint
  cluster_ca_certificate = base64decode(local.input.cluster_ca)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes = {
    host                   = local.input.cluster_endpoint
    cluster_ca_certificate = base64decode(local.input.cluster_ca)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
