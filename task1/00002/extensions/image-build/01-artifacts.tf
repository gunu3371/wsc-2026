resource "aws_s3_object" "dockerfile" {
  bucket       = data.aws_s3_bucket.artifacts.id
  key          = "private-build/image-build/Dockerfile"
  source       = "${path.module}/../../assets/shared/book-image/Dockerfile"
  etag         = filemd5("${path.module}/../../assets/shared/book-image/Dockerfile")
  content_type = "text/plain"
}

resource "aws_s3_object" "book_binary" {
  bucket = data.aws_s3_bucket.artifacts.id
  key    = "private-build/image-build/book"
  source = "${path.module}/../../assets/shared/book-image/book"
  etag   = filemd5("${path.module}/../../assets/shared/book-image/book")
}
