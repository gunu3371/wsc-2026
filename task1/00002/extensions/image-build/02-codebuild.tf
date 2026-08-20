data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "image_build" {
  name               = "wskorea26-image-build-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}

resource "aws_cloudwatch_log_group" "image_build" {
  name              = "/aws/codebuild/wskorea26-image-build"
  retention_in_days = 7
}

data "aws_iam_policy_document" "image_build" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [data.aws_ecr_repository.book.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.artifacts.arn}/private-build/image-build/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.s3.target_key_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.image_build.arn}:*"]
  }
}

resource "aws_iam_role_policy" "image_build" {
  name   = "wskorea26-image-build"
  role   = aws_iam_role.image_build.id
  policy = data.aws_iam_policy_document.image_build.json
}

resource "aws_codebuild_project" "image_build" {
  name           = "wskorea26-image-build"
  description    = "Build the official book binary image and push the stable tag to ECR"
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
      name  = "IMAGE_URI"
      value = "${data.aws_ecr_repository.book.repository_url}:stable"
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
            - mkdir -p assets
            - aws s3 cp "s3://$ARTIFACT_BUCKET/$DOCKERFILE_KEY" Dockerfile
            - aws s3 cp "s3://$ARTIFACT_BUCKET/$BOOK_BINARY_KEY" assets/book
            - aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin "$${IMAGE_URI%%/*}"
        build:
          commands:
            - docker build --platform linux/amd64 -t "$IMAGE_URI" .
            - docker push "$IMAGE_URI"
    YAML
  }

  tags = local.input.tags

  depends_on = [
    aws_iam_role_policy.image_build,
    aws_s3_object.dockerfile,
    aws_s3_object.book_binary,
  ]
}
