data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_secretsmanager_secret_version" "database" {
  secret_id = local.input.database_secret_arn
}

data "aws_ecr_repository" "application" {
  for_each = toset(["user", "product", "stress"])
  name     = "${local.input.project_name}-${each.key}"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

locals {
  db = jsondecode(data.aws_secretsmanager_secret_version.database.secret_string)

  common_tags = {
    Project     = local.input.project_name
    CandidateId = local.input.candidate_id
    Task        = "3"
    ManagedBy   = "Terraform"
  }

  app_images = {
    for name, repository in data.aws_ecr_repository.application :
    name => "${repository.repository_url}:${local.input.image_tag}"
  }

  app_ports = {
    user    = 8080
    product = 8080
    stress  = 8080
  }
}
