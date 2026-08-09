terraform {
  required_version = ">= 1.7.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" }
archive = { source = "hashicorp/archive", version = "~> 2.7" } }
}
provider "aws" { region = "us-east-1"
profile = var.aws_profile
default_tags { tags = { Project = "wsc2026", ManagedBy = "Terraform" } } }
variable "aws_profile" { type = string
default = null }
variable "candidate_id" { type = string }
variable "origin_image" { type = string }
variable "pillow_layer_arn" {
  description = "Published us-east-1 Lambda layer ARN containing Pillow for Python 3.12."
  type        = string
  validation {
    condition     = can(regex("^arn:[^:]+:lambda:us-east-1:[0-9]{12}:layer:[^:]+:[0-9]+$", var.pillow_layer_arn))
    error_message = "pillow_layer_arn must be a published Lambda layer ARN in us-east-1."
  }
}
data "aws_caller_identity" "current" {}
