data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "image_build" {
  name               = "wsc2026-book-image-build-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

resource "aws_kms_grant" "image_build" {
  name              = "wsc2026-book-image-build-decrypt"
  key_id            = local.input.bucket_kms_arn
  grantee_principal = aws_iam_role.image_build.arn
  operations        = ["Decrypt"]
}

resource "aws_cloudwatch_log_group" "image_build" {
  name              = "/aws/codebuild/wsc2026-book-image-build"
  retention_in_days = 7
}

data "aws_iam_policy_document" "image_build" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [data.aws_ecr_repository.book.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.artifacts.arn}/private-build/image-build/*"]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = [local.input.bucket_kms_arn]
  }
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.image_build.arn}:*"]
  }
}

resource "aws_iam_role_policy" "image_build" {
  name   = "wsc2026-book-image-build"
  role   = aws_iam_role.image_build.id
  policy = data.aws_iam_policy_document.image_build.json
}

resource "aws_codebuild_project" "image_build" {
  name           = "wsc2026-book-image-build"
  description    = "Build the official book binary and push v1.0.0"
  service_role   = aws_iam_role.image_build.arn
  build_timeout  = local.input.build_timeout_minutes
  queued_timeout = 30

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = data.aws_s3_bucket.artifacts.id
    }
    environment_variable {
      name  = "DOCKERFILE_KEY"
      value = aws_s3_object.dockerfile.key
    }
    environment_variable {
      name  = "BOOK_BINARY_KEY"
      value = aws_s3_object.book_binary.key
    }
    environment_variable {
      name  = "REPOSITORY_URI"
      value = data.aws_ecr_repository.book.repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.image_build.name
      stream_name = "book-image"
      status      = "ENABLED"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-YAML
      version: 0.2
      phases:
        pre_build:
          commands:
            - if aws ecr describe-images --repository-name wsc2026-book-ecr --image-ids imageTag=v1.0.0 >/dev/null 2>&1; then export IMAGE_EXISTS=true; else export IMAGE_EXISTS=false; fi
            - if [ "$IMAGE_EXISTS" = "false" ]; then mkdir -p assets; aws s3 cp "s3://$ARTIFACT_BUCKET/$DOCKERFILE_KEY" Dockerfile; aws s3 cp "s3://$ARTIFACT_BUCKET/$BOOK_BINARY_KEY" assets/book; aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin "$${REPOSITORY_URI%%/*}"; fi
        build:
          commands:
            - if [ "$IMAGE_EXISTS" = "false" ]; then docker build --platform linux/amd64 -t "$REPOSITORY_URI:v1.0.0" .; docker push "$REPOSITORY_URI:v1.0.0"; else echo "v1.0.0 already exists; skipping immutable tag push"; fi
    YAML
  }

  tags = local.input.tags

  depends_on = [
    aws_iam_role_policy.image_build,
    aws_kms_grant.image_build,
    aws_s3_object.dockerfile,
    aws_s3_object.book_binary,
  ]
}
