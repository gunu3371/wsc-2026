locals { static_bucket = "skills-book-static-2026-${var.candidate_id}" }
resource "aws_s3_bucket" "static" {
  bucket        = local.static_bucket
  force_destroy = var.force_destroy
  tags          = { Name = local.static_bucket }
}
resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_object" "static" {
  for_each = { "index.html" = "text/html", "main.jpeg" = "image/jpeg" }
  bucket       = aws_s3_bucket.static.id
  key          = each.key
  source       = "${path.module}/assets/${each.key}"
  etag         = filemd5("${path.module}/assets/${each.key}")
  content_type = each.value
}
resource "aws_cloudfront_origin_access_control" "static" {
  name                              = "skills-book-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_distribution" "book" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  origin {
    origin_id                = "static-s3"
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id
  }
  origin {
    origin_id   = "book-alb"
    domain_name = aws_lb.book.dns_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret
    }
  }
  default_cache_behavior {
    target_origin_id       = "static-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress               = true
  }
  ordered_cache_behavior {
    path_pattern           = "/v1/*"
    target_origin_id       = "book-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
    compress               = true
  }
  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
  tags = { Name = "skills-book-cloudfront" }
}
resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.static.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.book.arn } }
    }]
  })
}
output "cloudfront_domain" { value = aws_cloudfront_distribution.book.domain_name }
output "ecr_repository_url" { value = aws_ecr_repository.book.repository_url }

