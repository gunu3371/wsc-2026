resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.this.arn
}
resource "aws_s3_bucket_notification" "trigger" {
  bucket = aws_s3_bucket.this.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "input/"
    filter_suffix       = ".csv"
  }
  depends_on = [aws_lambda_permission.s3]
}

# The assignment starts the workflow by uploading the supplied sample after the
# notification and state machine are ready.  A later apply recreates the input
# if the workflow has already moved it to processed/.
resource "aws_s3_object" "test_csv" {
  bucket       = aws_s3_bucket.this.id
  key          = "input/test.csv"
  source       = "${path.module}/assets/test.csv"
  etag         = filemd5("${path.module}/assets/test.csv")
  content_type = "text/csv"
  depends_on   = [aws_s3_bucket_notification.trigger]
}

