data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  input       = merge(var.config.common, var.config.modules.platform)
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  kms_aliases = toset(["db", "ecr", "eks", "bucket", "function"])
  suffix      = coalesce(local.input.bucket_random_suffix, random_string.bucket.result)
  static_files = length(local.input.static_files) > 0 ? local.input.static_files : {
    "index.html" = "${path.module}/../assets/platform/index.html"
    "main.jpeg"  = "${path.module}/../assets/platform/main.jpeg"
  }
}

resource "random_string" "bucket" {
  length  = 4
  lower   = true
  upper   = false
  numeric = false
  special = false
}
