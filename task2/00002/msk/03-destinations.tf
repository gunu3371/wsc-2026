resource "aws_dynamodb_table" "data" {
  name         = "wsc2026-sensor-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sensorId"
  range_key    = "timestamp"
  attribute {
    name = "sensorId"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
}
resource "aws_s3_bucket" "alert" {
  bucket        = local.bucket
  force_destroy = true
}
resource "aws_s3_bucket_public_access_block" "alert" {
  bucket                  = aws_s3_bucket.alert.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
resource "aws_s3_object" "producer" {
  bucket      = aws_s3_bucket.alert.id
  key         = "bootstrap/app"
  source      = local.input.producer_binary_path
  source_hash = filemd5(local.input.producer_binary_path)
}
resource "aws_sns_topic" "alert" {
  name = "wsc2026-sensor-alert"
}
