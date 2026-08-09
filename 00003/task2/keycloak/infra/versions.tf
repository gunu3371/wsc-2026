terraform { required_version = ">= 1.7.0"
required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } } }
provider "aws" { region = "ap-northeast-2"
profile = var.aws_profile
default_tags { tags = { Project = "wsc2026", ManagedBy = "Terraform" } } }
variable "aws_profile" { type = string
default = null }
variable "keycloak_admin_password" { type = string
sensitive = true
default = "Skill53#!!@#" }
variable "saml_metadata_document" { type = string
sensitive = true
default = null }
data "aws_availability_zones" "available" { state = "available" }
data "aws_ssm_parameter" "al2023" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
data "aws_partition" "current" {}
