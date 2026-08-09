terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
}
provider "aws" { region = "us-east-1" }
data "aws_caller_identity" "current" {}

locals { bucket = "skillsphone-landing-ab-${data.aws_caller_identity.current.account_id}" }
resource "aws_s3_bucket" "landing" { bucket = local.bucket }
resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id
  block_public_acls = true
 block_public_policy = true
 ignore_public_acls = true
 restrict_public_buckets = true
}
resource "aws_s3_object" "a" { bucket = aws_s3_bucket.landing.id
 key = "version-a/index.html"
 source = "${path.module}/assets/index_a.html"
 content_type = "text/html"
 etag = filemd5("${path.module}/assets/index_a.html") }
resource "aws_s3_object" "b" { bucket = aws_s3_bucket.landing.id
 key = "version-b/index.html"
 source = "${path.module}/assets/index_b.html"
 content_type = "text/html"
 etag = filemd5("${path.module}/assets/index_b.html") }

resource "aws_cloudfront_key_value_store" "ab" { name = "skillsphone-cdn-ab-config"
 comment = "A/B routing configuration" }
resource "aws_cloudfrontkeyvaluestore_key" "weight" { key_value_store_arn = aws_cloudfront_key_value_store.ab.arn
 key = "weight"
 value = "0.3" }
resource "aws_cloudfrontkeyvaluestore_key" "a" { key_value_store_arn = aws_cloudfront_key_value_store.ab.arn
 key = "version_a"
 value = "/version-a/index.html" }
resource "aws_cloudfrontkeyvaluestore_key" "b" { key_value_store_arn = aws_cloudfront_key_value_store.ab.arn
 key = "version_b"
 value = "/version-b/index.html" }

resource "aws_cloudfront_function" "request" {
  name = "skillsphone-cdn-ab-req-fn"
 runtime = "cloudfront-js-2.0"
 publish = true
 code = file("${path.module}/assets/request.js")
  key_value_store_associations = [aws_cloudfront_key_value_store.ab.arn]
  depends_on = [aws_cloudfrontkeyvaluestore_key.weight, aws_cloudfrontkeyvaluestore_key.a, aws_cloudfrontkeyvaluestore_key.b]
}
resource "aws_cloudfront_function" "response" { name = "skillsphone-cdn-ab-res-fn"
 runtime = "cloudfront-js-2.0"
 publish = true
 code = file("${path.module}/assets/response.js") }
resource "aws_cloudfront_origin_access_control" "landing" { name = "skillsphone-cdn-ab-oac"
 origin_access_control_origin_type = "s3"
 signing_behavior = "always"
 signing_protocol = "sigv4" }
resource "aws_cloudfront_cache_policy" "ab" {
  name = "skillsphone-cdn-ab-cache-policy"
 min_ttl = 0
 default_ttl = 300
 max_ttl = 3600
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
 enable_accept_encoding_gzip = true
    cookies_config { cookie_behavior = "whitelist"
 cookies { items = ["x-sp-ab"] } }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
}
resource "aws_cloudfront_distribution" "ab" {
  enabled = true
 comment = "skillsphone-cdn-ab-distribution"
 default_root_object = "version-a/index.html"
 price_class = "PriceClass_200"
  origin { domain_name = aws_s3_bucket.landing.bucket_regional_domain_name
 origin_id = "landing-s3"
 origin_access_control_id = aws_cloudfront_origin_access_control.landing.id }
  default_cache_behavior {
    target_origin_id = "landing-s3"
 viewer_protocol_policy = "redirect-to-https"
 allowed_methods = ["GET", "HEAD"]
 cached_methods = ["GET", "HEAD"]
 compress = true
 cache_policy_id = aws_cloudfront_cache_policy.ab.id
    function_association { event_type = "viewer-request"
 function_arn = aws_cloudfront_function.request.arn }
    function_association { event_type = "viewer-response"
 function_arn = aws_cloudfront_function.response.arn }
  }
  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
}
resource "aws_s3_bucket_policy" "landing" {
  bucket = aws_s3_bucket.landing.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "CloudFrontRead", Effect = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = "s3:GetObject", Resource = "${aws_s3_bucket.landing.arn}/*", Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.ab.arn } } }] })
}
output "distribution_domain" { value = aws_cloudfront_distribution.ab.domain_name }
