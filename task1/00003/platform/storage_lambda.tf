resource "aws_s3_bucket" "static" {
  bucket        = "wsc2026-static-${local.suffix}-${lower(local.input.task_id)}-bucket"
  force_destroy = local.input.cleanup_mode
}
resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main["bucket"].arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_object" "static" {
  for_each               = local.static_files
  bucket                 = aws_s3_bucket.static.id
  key                    = "static/${each.key}"
  source                 = each.value
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.main["bucket"].arn
}

data "archive_file" "book_get" {
  type        = "zip"
  source_file = "${path.module}/../assets/platform/book_get.py"
  output_path = "${path.module}/book_get.zip"
}
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "book_function" {
  name               = "wsc2026-book-function-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_policy" "book_function" {
  name = "wsc2026-book-function-policy"
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:Query"], Resource = [aws_dynamodb_table.book.arn, "${aws_dynamodb_table.book.arn}/index/booking_id-index"]
      }, {
      Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:${data.aws_partition.current.partition}:logs:${local.input.region}:${data.aws_caller_identity.current.account_id}:*"
      }, {
      Effect = "Allow", Action = ["kms:Decrypt"], Resource = [aws_kms_key.main["function"].arn, aws_kms_key.main["db"].arn]
    }]
  })
}
resource "aws_iam_role_policy_attachment" "book_function" {
  role       = aws_iam_role.book_function.name
  policy_arn = aws_iam_policy.book_function.arn
}
resource "aws_lambda_function" "book_get" {
  function_name    = "wsc2026-book-get-function"
  role             = aws_iam_role.book_function.arn
  runtime          = "python3.12"
  handler          = "book_get.handler"
  filename         = data.archive_file.book_get.output_path
  source_code_hash = data.archive_file.book_get.output_base64sha256
  kms_key_arn      = aws_kms_key.main["function"].arn
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.book.name
    }
  }
}
resource "aws_lambda_function_url" "book_get" {
  function_name      = aws_lambda_function.book_get.function_name
  authorization_type = "NONE"
}
resource "aws_lambda_permission" "url" {
  statement_id           = "AllowFunctionURL"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.book_get.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
resource "aws_lambda_permission" "url_invoke" {
  statement_id             = "AllowFunctionURLInvoke"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.book_get.function_name
  principal                = "*"
  invoked_via_function_url = true
}
