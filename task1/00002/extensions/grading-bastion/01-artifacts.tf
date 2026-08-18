resource "aws_s3_object" "dockerfile" {
  bucket       = data.aws_s3_bucket.build_artifacts.id
  key          = "private-build/grading-bastion/Dockerfile"
  source       = "${path.module}/../../foundation/Dockerfile"
  etag         = filemd5("${path.module}/../../foundation/Dockerfile")
  content_type = "text/plain"
}

resource "aws_s3_object" "book_binary" {
  bucket = data.aws_s3_bucket.build_artifacts.id
  key    = "private-build/grading-bastion/book"
  source = "${path.module}/../../foundation/assets/book"
  etag   = filemd5("${path.module}/../../foundation/assets/book")
}
