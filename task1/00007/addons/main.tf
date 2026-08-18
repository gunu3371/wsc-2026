terraform {

  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    archive = {
      source = "hashicorp/archive", version = "~> 2.7"
    }
    kubernetes = {
      source = "hashicorp/kubernetes", version = "~> 2.36"
    }
    helm = {
      source = "hashicorp/helm", version = "~> 3.0"
    }
  }

}
provider "aws" {
  region = "ap-northeast-2"
}
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
variable "foundation_state_path" {
  type    = string
  default = "../foundation/terraform.tfstate"
}
variable "cluster_state_path" {
  type    = string
  default = "../cluster/terraform.tfstate"
}
variable "app_image" {
  type        = string
  description = "unicorn-concert-app:v1.0.0 immutable image URI"
}
variable "audit_principal_arn" {
  type        = string
  description = "Judge IAM principal allowed to assume the audit role"
}
variable "competitor_number" {
  type = string
}
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = var.foundation_state_path
  }
}
data "terraform_remote_state" "cluster" {
  backend = "local"
  config = {
    path = var.cluster_state_path
  }
}
data "aws_caller_identity" "current" {

}
data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.cluster.outputs.cluster_name
}
provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca)
  token                  = data.aws_eks_cluster_auth.main.token
}
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.cluster.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

resource "aws_iam_role" "app" {
  name = "unicorn-book-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "pods.eks.amazonaws.com"
        }, Action = ["sts:AssumeRole", "sts:TagSession"], Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }, ArnLike = {
          "aws:SourceArn" = "arn:aws:eks:ap-northeast-2:${data.aws_caller_identity.current.account_id}:podidentityassociation/${data.terraform_remote_state.cluster.outputs.cluster_name}/*"
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "app" {
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"], Resource = [data.terraform_remote_state.foundation.outputs.table_arn, "${data.terraform_remote_state.foundation.outputs.table_arn}/index/*"]
    }]
  })
}
resource "kubernetes_namespace_v1" "unicorn" {
  metadata {
    name = "unicorn"
  }
}
resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = "unicorn-book-app"
    namespace = "unicorn"
  }
}
resource "aws_eks_pod_identity_association" "app" {
  cluster_name    = data.terraform_remote_state.cluster.outputs.cluster_name
  namespace       = "unicorn"
  service_account = "unicorn-book-app"
  role_arn        = aws_iam_role.app.arn
}
resource "kubernetes_deployment_v1" "app" {

  metadata {
    name      = "unicorn-book-app-deploy"
    namespace = "unicorn"
    labels = {
      app = "unicorn-book-app"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "unicorn-book-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "unicorn-book-app"
        }
      }
      spec {
        service_account_name = "unicorn-book-app"
        node_selector = {
          unicorn = "app"
        }
        termination_grace_period_seconds = 30
        container {
          name  = "book"
          image = var.app_image
          port {
            container_port = 8080
          }
          env {
            name  = "AWS_REGION"
            value = "ap-northeast-2"
          }
          env {
            name  = "TABLE_NAME"
            value = "unicorn-concert-db"
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
          }
          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "sleep 10"]
              }
            }
          }
        }
      }
    }
  }
  depends_on = [aws_eks_pod_identity_association.app]

}
resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "unicorn-book-app-svc"
    namespace = "unicorn"
  }
  spec {
    selector = {
      app = "unicorn-book-app"
    }
    type = "NodePort"
    port {
      port        = 80
      target_port = "8080"
      node_port   = 30097
    }
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/assets/lambda.py"
  output_path = "${path.module}/lambda.zip"
}
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/unicorn/lambda/get-booking"
  retention_in_days = 30
  kms_key_id        = data.terraform_remote_state.foundation.outputs.platform_kms_arn
}
resource "aws_iam_role" "lambda" {
  name = "unicorn-get-booking-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "lambda.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query"], Resource = [data.terraform_remote_state.foundation.outputs.table_arn, "${data.terraform_remote_state.foundation.outputs.table_arn}/index/*"]
      }, {
      Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
    }]
  })
}
resource "aws_lambda_function" "get" {
  function_name    = "unicorn-get-booking-func"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "lambda.handler"
  runtime          = "python3.13"
  timeout          = 15
  kms_key_arn      = data.terraform_remote_state.foundation.outputs.app_kms_arn
  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda.name
    log_format = "JSON"
  }
  environment {
    variables = {
      TABLE_NAME = "unicorn-concert-db"
    }
  }
}

resource "aws_security_group" "alb" {
  name   = "unicorn-alb-sg"
  vpc_id = data.terraform_remote_state.foundation.outputs.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.97.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "alb_to_nodes" {

  type                     = "ingress"
  from_port                = 30097
  to_port                  = 30097
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = data.terraform_remote_state.cluster.outputs.cluster_security_group_id

}
resource "aws_lb" "main" {
  name               = "unicorn-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_target_group" "app" {
  name     = "unicorn-tg"
  port     = 30097
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.foundation.outputs.vpc_id
  health_check {
    path    = "/health"
    matcher = "200"
  }
}
resource "aws_lb_target_group" "lambda" {
  name        = "unicorn-lambda-tg"
  target_type = "lambda"
}
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}
resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.get.arn
  depends_on       = [aws_lambda_permission.alb]
}
data "aws_instances" "app" {
  filter {
    name   = "tag:Name"
    values = ["unicorn-k8snode-app-node"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}
resource "aws_lb_target_group_attachment" "app" {
  for_each         = toset(data.aws_instances.app.ids)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = each.value
  port             = 30097
  depends_on       = [kubernetes_service_v1.app]
}
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
resource "aws_lb_listener_rule" "get" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }
  condition {
    http_request_method {
      values = ["GET"]
    }
  }
  condition {
    path_pattern {
      values = ["/v1/book"]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "unicorn-web-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_vpc_origin" "alb" {
  vpc_origin_endpoint_config {
    name                   = "unicorn-alb-vpc-origin"
    arn                    = aws_lb.main.arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}
resource "aws_cloudfront_distribution" "main" {

  enabled             = true
  comment             = "unicorn-svc-cf"
  default_root_object = "index.html"
  origin {
    domain_name              = "${data.terraform_remote_state.foundation.outputs.bucket_name}.s3.ap-northeast-2.amazonaws.com"
    origin_id                = "web"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "api"
    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.alb.id
    }
  }
  default_cache_behavior {
    target_origin_id       = "web"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern           = "/v1/*"
    target_origin_id       = "api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    forwarded_values {
      query_string = true
      headers      = ["Content-Type"]
      cookies {
        forward = "all"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern           = "/health"
    target_origin_id       = "api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  web_acl_id = aws_wafv2_web_acl.main.arn

}
resource "aws_s3_bucket_policy" "web" {
  bucket = data.terraform_remote_state.foundation.outputs.bucket_name
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "cloudfront.amazonaws.com"
        }, Action = "s3:GetObject", Resource = "arn:aws:s3:::${data.terraform_remote_state.foundation.outputs.bucket_name}/*", Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })
}
resource "aws_wafv2_web_acl" "main" {
  provider = aws.use1
  name     = "unicorn-waf"
  scope    = "CLOUDFRONT"
  default_action {
    allow {

    }
  }
  custom_response_body {
    key          = "blocked"
    content      = "Request blocked"
    content_type = "TEXT_PLAIN"
  }
  rule {
    name     = "AWSCommonRules"
    priority = 10
    override_action {
      none {

      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "unicorn-common"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWSKnownBadInputs"
    priority = 20
    override_action {
      none {

      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "unicorn-bad"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "unicorn-rate-limit"
    priority = 30
    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "blocked"
        }
      }
    }
    statement {
      rate_based_statement {
        limit                 = 50
        evaluation_window_sec = 60
        aggregate_key_type    = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "unicorn-rate"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "unicorn-waf"
    sampled_requests_enabled   = true
  }
}
resource "aws_cloudwatch_log_group" "waf" {
  provider          = aws.use1
  name              = "aws-waf-logs-unicorn"
  retention_in_days = 30
  kms_key_id        = data.terraform_remote_state.foundation.outputs.platform_use1_kms_arn
}
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  provider                = aws.use1
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}

resource "aws_iam_role" "audit" {
  name                 = "unicorn-audit-role"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        AWS = var.audit_principal_arn
        }, Action = "sts:AssumeRole", Condition = {
        StringEquals = {
          "sts:ExternalId" = "unicorn-audit-2026${var.competitor_number}"
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "audit" {
  role = aws_iam_role.audit.id
  name = "unicorn-audit-readonly"
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query"], Resource = [data.terraform_remote_state.foundation.outputs.table_arn, "${data.terraform_remote_state.foundation.outputs.table_arn}/index/*"]
      }, {
      Effect = "Allow", Action = ["ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeRouteTables", "ec2:DescribeVpcEndpoints", "ec2:DescribeFlowLogs", "eks:DescribeCluster", "eks:ListNodegroups", "eks:DescribeNodegroup"], Resource = "*"
    }]
  })
}

resource "helm_release" "monitoring" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  values = [yamlencode({
    prometheusOperator = {
      nodeSelector = {
        unicorn = "addon"
      }
      }, grafana = {
      nodeSelector = {
        unicorn = "addon"
        }, dashboards = {
        default = {
          unicorn-grafana-dashboard = {
            json = jsonencode({
              title = "unicorn-grafana-dashboard", uid = "unicorn-grafana-dashboard", schemaVersion = 39, panels = []
            })
          }
        }
      }
      }, prometheus = {
      prometheusSpec = {
        nodeSelector = {
          unicorn = "addon"
        }
      }
    }
  })]
}
resource "aws_iam_role" "fluentbit" {
  name               = "unicorn-fluentbit-role"
  assume_role_policy = aws_iam_role.app.assume_role_policy
}
resource "aws_iam_role_policy" "fluentbit" {
  role = aws_iam_role.fluentbit.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"], Resource = "arn:aws:logs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:log-group:/unicorn/eks/book-app:*"
    }]
  })
}
resource "kubernetes_service_account_v1" "fluentbit" {
  metadata {
    name      = "unicorn-fluent-bit"
    namespace = "unicorn"
  }
}
resource "aws_eks_pod_identity_association" "fluentbit" {
  cluster_name    = data.terraform_remote_state.cluster.outputs.cluster_name
  namespace       = "unicorn"
  service_account = "unicorn-fluent-bit"
  role_arn        = aws_iam_role.fluentbit.arn
}
resource "kubernetes_config_map_v1" "fluentbit" {

  metadata {
    name      = "unicorn-fluent-bit"
    namespace = "unicorn"
  }
  data = {
    "fluent-bit.conf" = <<-CONF
    [SERVICE]
        Flush 1
        Log_Level info
        Parsers_File parsers.conf
    [INPUT]
        Name tail
        Path /var/log/containers/unicorn-book-app-*_unicorn_book-*.log
        Tag book.*
        Parser cri
        Mem_Buf_Limit 10MB
    [FILTER]
        Name grep
        Match book.*
        Exclude log /health
    [FILTER]
        Name parser
        Match book.*
        Key_Name log
        Parser json
        Reserve_Data Off
    [OUTPUT]
        Name cloudwatch_logs
        Match book.*
        region ap-northeast-2
        log_group_name /unicorn/eks/book-app
        log_stream_prefix book-
        auto_create_group false
    CONF
    "parsers.conf"    = <<-CONF
    [PARSER]
        Name cri
        Format regex
        Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    [PARSER]
        Name json
        Format json
    CONF

  }

}
resource "kubernetes_daemon_set_v1" "fluentbit" {

  metadata {
    name      = "unicorn-fluent-bit"
    namespace = "unicorn"
    labels = {
      app = "unicorn-fluent-bit"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "unicorn-fluent-bit"
      }
    }
    template {
      metadata {
        labels = {
          app = "unicorn-fluent-bit"
        }
      }
      spec {
        service_account_name = "unicorn-fluent-bit"
        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:2.34.0"
          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc"
          }
          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }
        }
        volume {
          name = "config"
          config_map {
            name = "unicorn-fluent-bit"
          }
        }
        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
      }
    }
  }
  depends_on = [aws_eks_pod_identity_association.fluentbit]

}
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.main.domain_name
}
