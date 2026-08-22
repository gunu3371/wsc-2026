data "aws_s3_bucket" "artifacts" {
  bucket = local.input.static_bucket_name
}

data "aws_ecr_repository" "book" {
  name = "wsc2026-book-ecr"
}
