data "archive_file" "remediation" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/remediation.zip"
}
resource "aws_iam_role" "lambda" {
  name = "wsc2026-event-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "lambda.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["ec2:StartInstances", "ec2:StopInstances", "ec2:ModifyInstanceAttribute", "ec2:RevokeSecurityGroupIngress", "ec2:Describe*", "ec2:ReplaceIamInstanceProfileAssociation"], Resource = "*"
      }, {
      Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.ec2.arn
      }, {
      Effect = "Allow", Action = "sns:Publish", Resource = aws_sns_topic.alert.arn
      }, {
      Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*"
    }]
  })
}
locals {
  functions = {
    "wsc2026-ec2-stop-remediation" = "stop_handler",
    "wsc2026-ec2-terminate-alert"  = "terminate_handler",
    "wsc2026-sg-remediation"       = "sg_handler",
    "wsc2026-tag-alert"            = "tag_handler",
    "wsc2026-role-remediation"     = "role_handler",
    "wsc2026-ec2-type-remediation" = "type_handler"
  }
}
resource "aws_lambda_function" "fn" {
  for_each         = local.functions
  function_name    = each.key
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.remediation.output_path
  source_code_hash = data.archive_file.remediation.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alert.arn, INSTANCE_ID = aws_instance.event.id, SECURITY_GROUP_ID = aws_security_group.event.id, ROLE_NAME = aws_iam_instance_profile.ec2.name, INSTANCE_TYPE = "t3.micro"
    }
  }
}

