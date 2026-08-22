data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  input       = merge(var.config.common, var.config.modules.platform)
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  kms_aliases = toset(["db", "ecr", "eks", "bucket", "function"])
  static_files = length(local.input.static_files) > 0 ? local.input.static_files : {
    "index.html" = "${path.module}/../assets/platform/index.html"
    "main.jpeg"  = "${path.module}/../assets/platform/main.jpeg"
  }
}
