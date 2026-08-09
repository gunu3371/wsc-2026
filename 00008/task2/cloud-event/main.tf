data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.73.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "skills-ceh-vpc" }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.73.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = false
  tags = { Name = "skills-ceh-private-subnet" }
}

resource "aws_security_group" "protected" {
  name        = "skills-ceh-protected-sg"
  description = "Protected group: ingress must remain empty"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-ceh-protected-sg" }
}

resource "aws_instance" "protected" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.protected.id]
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }
  tags = { Name = "skills-ceh-ec2" }
}

resource "aws_sns_topic" "alert" {
  name = "skills-ceh-alert-topic"
  tags = { Name = "skills-ceh-alert-topic" }
}

data "archive_file" "remediation" {
  type        = "zip"
  source_file = "${path.module}/lambda/remediate_security_group.py"
  output_path = "${path.module}/remediation.zip"
}

resource "aws_iam_role" "lambda" {
  name = "skills-ceh-remediate-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "skills-ceh-remediate-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeSecurityGroups", "ec2:RevokeSecurityGroupIngress"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alert.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/skills-ceh-remediate-fn"
  retention_in_days = 30
}

resource "aws_lambda_function" "remediation" {
  function_name    = "skills-ceh-remediate-fn"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "remediate_security_group.lambda_handler"
  timeout          = 30
  filename         = data.archive_file.remediation.output_path
  source_code_hash = data.archive_file.remediation.output_base64sha256
  environment {
    variables = {
      PROTECTED_SECURITY_GROUP_ID = aws_security_group.protected.id
      SNS_TOPIC_ARN               = aws_sns_topic.alert.arn
    }
  }
  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]
  tags       = { Name = "skills-ceh-remediate-fn" }
}

resource "aws_cloudwatch_event_rule" "sg_change" {
  name           = "skills-ceh-sg-change-rule"
  event_bus_name = "default"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName   = ["AuthorizeSecurityGroupIngress"]
    }
  })
  tags = { Name = "skills-ceh-sg-change-rule" }
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule           = aws_cloudwatch_event_rule.sg_change.name
  event_bus_name = "default"
  target_id      = "skills-ceh-remediate-fn"
  arn            = aws_lambda_function.remediation.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sg_change.arn
}

resource "aws_s3_bucket" "trail" {
  bucket        = "skills-ceh-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
  tags          = { Name = "skills-ceh-cloudtrail" }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
        Condition = { StringEquals = { "AWS:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:ap-southeast-1:${data.aws_caller_identity.current.account_id}:trail/skills-ceh-cloudtrail" } }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudtrail:ap-southeast-1:${data.aws_caller_identity.current.account_id}:trail/skills-ceh-cloudtrail"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "skills-ceh-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true
  depends_on                    = [aws_s3_bucket_policy.trail]
  tags                          = { Name = "skills-ceh-cloudtrail" }
}

variable "force_destroy" {
  type    = bool
  default = false
}

output "protected_security_group_id" { value = aws_security_group.protected.id }
output "topic_arn" { value = aws_sns_topic.alert.arn }
