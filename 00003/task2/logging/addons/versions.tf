terraform { required_version = ">= 1.7.0"
required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" }
kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.36" }
helm = { source = "hashicorp/helm", version = "~> 3.0" } } }
provider "aws" { region = "ap-northeast-1"
profile = var.aws_profile }
variable "aws_profile" { type = string
default = null }
variable "cluster_name" { type = string
default = "wsc2026-logging-cluster" }
variable "log_generator_image" { type = string
default = "python:3.13-alpine" }
data "aws_eks_cluster" "main" { name = var.cluster_name }
data "aws_eks_cluster_auth" "main" { name = var.cluster_name }
provider "kubernetes" { host = data.aws_eks_cluster.main.endpoint
cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
token = data.aws_eks_cluster_auth.main.token }
provider "helm" { kubernetes = { host = data.aws_eks_cluster.main.endpoint
cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
token = data.aws_eks_cluster_auth.main.token } }
