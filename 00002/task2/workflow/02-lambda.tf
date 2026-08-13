data "archive_file" "processor" {
  type = "zip"
  source {
    content  = file("${path.module}/lambda/processor.py")
    filename = "index.py"
  }
  output_path = "${path.module}/processor.zip"
}
data "archive_file" "trigger" {
  type        = "zip"
  source_file = "${path.module}/lambda/trigger.py"
  output_path = "${path.module}/trigger.zip"
}
resource "aws_iam_role" "lambda" {
  name = "wsc2026-lambda-student-role"
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
      Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.this.arn}/*"
      }, {
      Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.this.arn
      }, {
      Effect = "Allow", Action = ["states:StartExecution"], Resource = aws_sfn_state_machine.this.arn
      }, {
      Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*"
    }]
  })
}
resource "aws_lambda_function" "processor" {
  function_name    = "wsc2026-student-score-function"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "index.handler"
  filename         = data.archive_file.processor.output_path
  source_code_hash = data.archive_file.processor.output_base64sha256
  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.this.id, DDB_TABLE = aws_dynamodb_table.this.name
    }
  }
}
resource "aws_lambda_function" "trigger" {
  function_name    = "wsc2026-student-score-trigger"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "trigger.handler"
  filename         = data.archive_file.trigger.output_path
  source_code_hash = data.archive_file.trigger.output_base64sha256
  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.this.arn
    }
  }
}

