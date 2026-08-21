data "aws_s3_bucket" "artifacts" {
  bucket = local.input.s3_bucket_name
}

data "aws_ecr_repository" "book" {
  name = "wskorea26-book-repo"
}

data "aws_kms_alias" "s3" {
  name = "alias/wskorea26-s3-key"
}
