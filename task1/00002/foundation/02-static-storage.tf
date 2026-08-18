data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "Root"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}
data "aws_iam_policy_document" "kms_s3" {
  statement {
    sid       = "Root"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
    }
  }
}
resource "aws_kms_key" "s3" {
  description             = "wskorea26 S3"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms_s3.json
}
resource "aws_kms_alias" "s3" {
  name          = "alias/wskorea26-s3-key"
  target_key_id = aws_kms_key.s3.key_id
}
resource "aws_s3_bucket" "web" {
  bucket        = local.bucket
  force_destroy = true
}
resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_object" "web" {
  for_each = {
    "web/main/index.html" = "${path.module}/../assets/foundation/index.html", "web/main/main.jpeg" = "${path.module}/../assets/foundation/main.jpeg"
  }
  bucket                 = aws_s3_bucket.web.id
  key                    = each.key
  source                 = each.value
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.s3.arn
  content_type           = endswith(each.key, ".html") ? "text/html" : "image/jpeg"
}
