resource "aws_s3_bucket" "this" {
  bucket        = local.bucket
  force_destroy = true
}
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
resource "aws_s3_object" "folders" {
  for_each = toset(["input/", "processed/", "error/"])
  bucket   = aws_s3_bucket.this.id
  key      = each.value
  content  = ""
}
resource "aws_dynamodb_table" "this" {
  name         = "wsc2026-student-score"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "studentId"
  range_key    = "examDate"
  attribute {
    name = "studentId"
    type = "S"
  }
  attribute {
    name = "examDate"
    type = "S"
  }
}
