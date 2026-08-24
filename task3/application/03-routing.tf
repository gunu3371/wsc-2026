data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name        = "${local.input.project_name}-alb"
  description = "Allow CloudFront origin traffic to the task 3 ALB"
  vpc_id      = local.input.vpc_id

  ingress {
    description     = "HTTP from CloudFront origin-facing addresses"
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_origin.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.input.project_name}-alb" }
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${local.input.project_name}-alb-logs-${local.input.candidate_id}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-task-logs"
    status = "Enabled"
    filter {}
    expiration { days = 1 }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid       = "AllowALBLogDeliveryAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.alb_logs.arn]
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "AllowALBLogDeliveryWrite"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:elasticloadbalancing:${local.input.aws_region}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

resource "kubernetes_ingress_v1" "application" {
  metadata {
    name      = "application"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/group.name"                          = local.alb_group_name
      "alb.ingress.kubernetes.io/group.order"                         = "10"
      "alb.ingress.kubernetes.io/healthcheck-path"                    = "/healthcheck"
      "alb.ingress.kubernetes.io/healthcheck-protocol"                = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"                        = jsonencode([{ HTTP = 80 }])
      "alb.ingress.kubernetes.io/load-balancer-attributes"            = "access_logs.s3.enabled=true,access_logs.s3.bucket=${aws_s3_bucket.alb_logs.id},access_logs.s3.prefix=alb,routing.http.drop_invalid_header_fields.enabled=true"
      "alb.ingress.kubernetes.io/load-balancer-name"                  = local.alb_name
      "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "true"
      "alb.ingress.kubernetes.io/scheme"                              = "internet-facing"
      "alb.ingress.kubernetes.io/security-groups"                     = aws_security_group.alb.id
      "alb.ingress.kubernetes.io/subnets"                             = join(",", local.input.public_subnet_ids)
      "alb.ingress.kubernetes.io/success-codes"                       = "200"
      "alb.ingress.kubernetes.io/target-type"                         = "ip"
    }
  }

  wait_for_load_balancer = true

  spec {
    ingress_class_name = "alb"
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

  depends_on = [
    helm_release.load_balancer_controller,
    aws_s3_bucket_policy.alb_logs,
  ]
}

resource "kubernetes_ingress_v1" "fallback" {
  metadata {
    name      = "application-fallback"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/actions.fixed-404" = jsonencode({ type = "fixed-response", fixedResponseConfig = { contentType = "text/plain", statusCode = "404", messageBody = "Not Found" } })
      "alb.ingress.kubernetes.io/group.name"        = local.alb_group_name
      "alb.ingress.kubernetes.io/group.order"       = "1000"
      "alb.ingress.kubernetes.io/target-type"       = "ip"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "fixed-404"
              port { name = "use-annotation" }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_ingress_v1.application]
}

data "aws_lb" "application" {
  name = local.alb_name

  depends_on = [kubernetes_ingress_v1.application, kubernetes_ingress_v1.fallback]
}

resource "aws_cloudfront_origin_access_control" "images" {
  name                              = "${local.input.project_name}-images"
  description                       = "Private image bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "image_path" {
  name    = "${local.input.project_name}-image-path"
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
  name     = "${local.input.project_name}-edge"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = {
      for index, user_agent in sort(tolist(local.input.blocked_user_agents)) :
      user_agent => index
    }

    content {
      name     = format("UserAgent-%02d", rule.value + 1)
      priority = rule.value + 1

      action {
        dynamic "block" {
          for_each = upper(local.input.blocked_user_agent_action) == "BLOCK" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = upper(local.input.blocked_user_agent_action) == "COUNT" ? [1] : []
          content {}
        }
      }

      statement {
        byte_match_statement {
          search_string         = lower(trimspace(rule.key))
          positional_constraint = "EXACTLY"

          field_to_match {
            single_header { name = "user-agent" }
          }

          text_transformation {
            priority = 0
            type     = "LOWERCASE"
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = format("user-agent-%02d", rule.value + 1)
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 100
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
    priority = 200
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
    priority = 300
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
    metric_name                = "${local.input.project_name}-edge"
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
    domain_name = data.aws_lb.application.dns_name
    origin_id   = "application-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = "${local.input.image_bucket_name}.s3.${local.input.aws_region}.amazonaws.com"
    origin_id                = "image-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.images.id
  }

  default_cache_behavior {
    target_origin_id         = "application-alb"
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
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${local.input.image_bucket_name}/*"]
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
  bucket = local.input.image_bucket_name
  policy = data.aws_iam_policy_document.image_bucket.json
}
