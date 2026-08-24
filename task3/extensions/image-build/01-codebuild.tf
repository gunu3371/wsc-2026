resource "aws_s3_bucket" "source" {
  bucket        = local.source_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket = aws_s3_bucket.source.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source" {
  bucket = aws_s3_bucket.source.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "source" {
  bucket = aws_s3_bucket.source.id
  rule {
    id     = "expire-build-inputs"
    status = "Enabled"
    filter {}
    expiration { days = 1 }
  }
}

resource "aws_s3_object" "dockerfile" {
  bucket = aws_s3_bucket.source.id
  key    = local.dockerfile_key
  source = "${path.module}/../../assets/shared/Dockerfile.binary"
  etag   = filemd5("${path.module}/../../assets/shared/Dockerfile.binary")
}

resource "aws_s3_object" "build_targets" {
  bucket  = aws_s3_bucket.source.id
  key     = local.build_targets_key
  content = jsonencode(local.build_targets)
  etag    = md5(jsonencode(local.build_targets))
}

resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/${local.project_name}"
  retention_in_days = local.input.log_retention_days
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "build" {
  name               = local.project_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "build" {
  statement {
    sid       = "ReadBuildInputs"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.source.arn}/*"]
  }

  statement {
    sid       = "ListBuildInputs"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.source.arn]
  }

  statement {
    sid       = "ECRAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushApplicationImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      for name in sort(keys(local.repository_names)) :
      "arn:${data.aws_partition.current.partition}:ecr:${local.input.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${local.repository_names[name]}"
    ]
  }

  statement {
    sid = "WriteBuildLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.build.arn}:*"]
  }
}

resource "aws_iam_role_policy" "build" {
  name   = "build-and-push-images"
  role   = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.build.json
}

resource "aws_codebuild_project" "application" {
  name           = local.project_name
  description    = "Build task 3 official binaries and push linux/amd64 images to ECR"
  service_role   = aws_iam_role.build.arn
  build_timeout  = 30
  queued_timeout = 30

  artifacts { type = "NO_ARTIFACTS" }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = local.input.compute_type
    image                       = local.input.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = local.input.aws_region
    }
    environment_variable {
      name  = "SOURCE_BUCKET"
      value = aws_s3_bucket.source.id
    }
    environment_variable {
      name  = "DOCKERFILE_KEY"
      value = aws_s3_object.dockerfile.key
    }
    environment_variable {
      name  = "BUILD_TARGETS_KEY"
      value = aws_s3_object.build_targets.key
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.build.name
      stream_name = "build"
      status      = "ENABLED"
    }
  }

  source {
    type = "NO_SOURCE"
    buildspec = yamlencode({
      version = 0.2
      env     = { shell = "bash" }
      phases = {
        pre_build = {
          commands = [
            "set -euo pipefail",
            "aws s3 cp \"s3://$SOURCE_BUCKET/$BUILD_TARGETS_KEY\" ./build-targets.json",
            "jq --version",
            "REGISTRY=$(jq -r 'to_entries[0].value.repository_url' build-targets.json | cut -d/ -f1)",
            "aws ecr get-login-password --region \"$AWS_DEFAULT_REGION\" | docker login --username AWS --password-stdin \"$REGISTRY\"",
            "aws s3 cp \"s3://$SOURCE_BUCKET/$DOCKERFILE_KEY\" ./Dockerfile.binary",
          ]
        }
        build = {
          commands = [
            <<-BUILD
              jq -r 'keys[]' build-targets.json | while read -r APP; do
                BINARY_KEY=$(jq -r --arg app "$APP" '.[$app].binary_object_key' build-targets.json)
                REPOSITORY=$(jq -r --arg app "$APP" '.[$app].repository_url' build-targets.json)
                IMAGE_TAG=$(jq -r --arg app "$APP" '.[$app].image_tag' build-targets.json)
                aws s3 cp "s3://$SOURCE_BUCKET/$BINARY_KEY" "./$APP"
                docker build --platform linux/amd64 -f Dockerfile.binary --build-arg "BINARY=$APP" -t "$REPOSITORY:$IMAGE_TAG" .
                docker push "$REPOSITORY:$IMAGE_TAG"
              done
            BUILD
          ]
        }
      }
    })
  }

  depends_on = [aws_iam_role_policy.build]
}
