data "aws_s3_bucket" "artifacts" {
  bucket = local.input.bucket_name
}

data "aws_ecr_repository" "book" {
  name = "unicorn-concert-app"
}
