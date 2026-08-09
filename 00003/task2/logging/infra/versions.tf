terraform { required_version = ">= 1.7.0"
required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } } }
provider "aws" { region = "ap-northeast-1"
profile = var.aws_profile
default_tags { tags = { Project = "wsc2026", ManagedBy = "Terraform" } } }
variable "aws_profile" { type = string
default = null }
data "aws_partition" "current" {}
