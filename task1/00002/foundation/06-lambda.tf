data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "lambda" {
  name               = "wskorea26-book-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "lambda_ddb" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["dynamodb:Scan"], Resource = aws_dynamodb_table.book.arn
      },
      {
        Effect = "Allow", Action = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.ddb.arn
      }
    ]
  })
}
data "archive_file" "book" {
  type        = "zip"
  source_file = "${path.module}/../assets/foundation/lambda/book.py"
  output_path = "${path.module}/book.zip"
}
resource "aws_lambda_function" "book" {
  function_name    = "wskorea26-book-lambda"
  role             = aws_iam_role.lambda.arn
  runtime          = local.input.lambda_runtime
  handler          = "book.handler"
  filename         = data.archive_file.book.output_path
  source_code_hash = data.archive_file.book.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.book.name
    }
  }
}
