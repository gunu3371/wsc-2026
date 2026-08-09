terraform {
  required_version = ">= 1.7.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" }
archive = { source = "hashicorp/archive", version = "~> 2.7" } }
}
provider "aws" { region = "ap-southeast-1"
profile = var.aws_profile
default_tags { tags = { Project = "wsc2026", ManagedBy = "Terraform" } } }
variable "aws_profile" { type = string
default = null }
variable "orders_file" { type = string
default = "assets/sample-orders.json" }
variable "inventory_file" { type = string
default = "assets/inventory-seed.json" }
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
