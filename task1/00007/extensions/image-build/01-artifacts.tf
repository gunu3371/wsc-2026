resource "aws_s3_object" "dockerfile" {
  bucket                 = data.aws_s3_bucket.artifacts.id
  key                    = "private-build/image-build/Dockerfile"
  source                 = "${path.module}/../../assets/shared/book-image/Dockerfile"
  source_hash            = filemd5("${path.module}/../../assets/shared/book-image/Dockerfile")
  content_type           = "text/plain"
  server_side_encryption = "aws:kms"
  kms_key_id             = local.input.data_kms_arn
}

resource "aws_s3_object" "book_binary" {
  bucket                 = data.aws_s3_bucket.artifacts.id
  key                    = "private-build/image-build/book"
  source                 = "${path.module}/../../assets/shared/book-image/book"
  source_hash            = filemd5("${path.module}/../../assets/shared/book-image/book")
  server_side_encryption = "aws:kms"
  kms_key_id             = local.input.data_kms_arn
}
