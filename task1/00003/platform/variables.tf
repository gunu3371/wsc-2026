variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "candidate_id" {
  type = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.candidate_id))
    error_message = "candidate_id must be usable in an S3 bucket name."
  }
}

variable "bucket_random_suffix" {
  type    = string
  default = null
}

variable "image_uri" {
  type    = string
  default = "public.ecr.aws/docker/library/nginx:1.27"
}

variable "alb_domain_name" {
  type    = string
  default = "example.invalid"
}

variable "eks_endpoint_public_access" {
  description = "Temporarily enable the EKS public endpoint for a CIDR-restricted administrative apply."
  type        = bool
  default     = false
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed when eks_endpoint_public_access is enabled."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.eks_endpoint_public_access || length(var.eks_public_access_cidrs) > 0
    error_message = "eks_public_access_cidrs must not be empty when the public endpoint is enabled."
  }
}

variable "cleanup_mode" {
  description = "Enable only for the documented two-phase destroy procedure. It first disables DynamoDB deletion protection and permits removal of S3 object versions and ECR images."
  type        = bool
  default     = false
}

variable "static_files" {
  description = "Optional replacement map of object name to local path. Bundled index.html and main.jpeg are used when empty."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  kms_aliases = toset(["db", "ecr", "eks", "bucket", "function"])
  suffix      = coalesce(var.bucket_random_suffix, random_string.bucket.result)
  static_files = length(var.static_files) > 0 ? var.static_files : {
    "index.html" = "${path.module}/index.html"
    "main.jpeg"  = "${path.module}/main.jpeg"
  }
}

resource "random_string" "bucket" {
  length  = 4
  lower   = true
  upper   = false
  numeric = false
  special = false
}
