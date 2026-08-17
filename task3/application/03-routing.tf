resource "kubernetes_ingress_v1" "application" {
  metadata {
    name      = "application"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "5"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    }
  }

  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        dynamic "path" {
          for_each = {
            "/v1/user"     = "user"
            "/v1/product"  = "product"
            "/v1/stress"   = "stress"
            "/healthcheck" = "user"
          }
          content {
            path      = path.key
            path_type = "Prefix"
            backend {
              service {
                name = kubernetes_service_v1.application[path.value].metadata[0].name
                port { number = 80 }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.ingress_nginx]
}

resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "${var.project_name}-images"
  description                       = "Private image bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "image_path" {
  name    = "${var.project_name}-image-path"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      request.uri = request.uri.replace(/^\/images\/?/, '/');
      return request;
    }
  JS
}

resource "aws_wafv2_web_acl" "main" {
  provider = aws.us_east_1
  name     = "${var.project_name}-edge"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # The official product PUT uploads an image in the request body. Keep
        # body-oriented generic rules observable without blocking valid binary
        # uploads whose exact Content-Type is missing from v1.0.0.
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }
        rule_action_override {
          name = "GenericRFI_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "PerIpRateLimit"
    priority = 30
    action {
      block {}
    }
    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = 10000
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-edge"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Task 3 single public endpoint"
  price_class     = "PriceClass_200"
  web_acl_id      = aws_wafv2_web_acl.main.arn

  origin {
    domain_name = data.kubernetes_service_v1.ingress.status[0].load_balancer[0].ingress[0].hostname
    origin_id   = "application-nlb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = "${var.image_bucket_name}.s3.${var.aws_region}.amazonaws.com"
    origin_id                = "image-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
  }

  default_cache_behavior {
    target_origin_id         = "application-nlb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "image-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.image_path.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  depends_on = [kubernetes_ingress_v1.application]
}

data "aws_iam_policy_document" "image_bucket" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.image_bucket_name}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket = var.image_bucket_name
  policy = data.aws_iam_policy_document.image_bucket.json
}
