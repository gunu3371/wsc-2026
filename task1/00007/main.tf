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
  }

}
provider "aws" {
  region = "ap-northeast-2"
}
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
data "aws_caller_identity" "current" {

}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}
provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
locals {
  azs           = slice(data.aws_availability_zones.available.names, 0, 3)
  public_cidrs  = ["10.97.0.0/24", "10.97.1.0/24", "10.97.2.0/24"]
  private_cidrs = ["10.97.10.0/24", "10.97.11.0/24", "10.97.12.0/24"]
  web_bucket    = "unicorn-web-${data.aws_caller_identity.current.account_id}"
}
resource "aws_vpc" "this" {
  cidr_block           = "10.97.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "unicorn-vpc"
  }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "unicorn-igw"
  }
}
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "unicorn-subnet-pub-${substr(local.azs[count.index], -1, 1)}", "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name = "unicorn-subnet-priv-${substr(local.azs[count.index], -1, 1)}", "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_eip" "nat" {
  count      = 3
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
}
resource "aws_nat_gateway" "this" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "unicorn-nat-${substr(local.azs[count.index], -1, 1)}"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "unicorn-rt-public"
  }
}
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = {
    Name = "unicorn-rt-private-${substr(local.azs[count.index], -1, 1)}"
  }
}
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/unicorn/vpc/flow"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.platform.arn
}
resource "aws_iam_role" "flow" {
  name = "unicorn-vpc-flow-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}
resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
}
resource "aws_security_group" "endpoint" {
  name   = "unicorn-endpoint-sg"
  vpc_id = aws_vpc.this.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ecr.api", "ecr.dkr", "logs", "sts", "ec2", "eks"])
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.ap-northeast-2.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoint.id]
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.ap-northeast-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
}
resource "aws_kms_key" "app" {
  description             = "Unicorn application"
  enable_key_rotation     = true
  rotation_period_in_days = 90
}
resource "aws_kms_alias" "app" {
  name          = "alias/unicorn-kms-app"
  target_key_id = aws_kms_key.app.key_id
}
resource "aws_kms_key" "data" {
  description             = "Unicorn data"
  enable_key_rotation     = true
  rotation_period_in_days = 90
}
resource "aws_kms_alias" "data" {
  name          = "alias/unicorn-kms-data"
  target_key_id = aws_kms_key.data.key_id
}
resource "aws_kms_key" "platform" {
  description             = "Unicorn platform"
  enable_key_rotation     = true
  rotation_period_in_days = 90
  multi_region            = true
}
resource "aws_kms_alias" "platform" {
  name          = "alias/unicorn-kms-platform"
  target_key_id = aws_kms_key.platform.key_id
}
resource "aws_kms_replica_key" "platform_use1" {
  provider        = aws.use1
  primary_key_arn = aws_kms_key.platform.arn
  description     = "Unicorn platform us-east-1"
}
resource "aws_kms_alias" "platform_use1" {
  provider      = aws.use1
  name          = "alias/unicorn-kms-platform"
  target_key_id = aws_kms_replica_key.platform_use1.key_id
}
resource "aws_s3_bucket" "web" {
  bucket = local.web_bucket
}
resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "web" {
  bucket = aws_s3_bucket.web.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_object" "index" {
  bucket                 = aws_s3_bucket.web.id
  key                    = "index.html"
  source                 = "${path.module}/assets/index.html"
  content_type           = "text/html"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data.arn
  etag                   = filemd5("${path.module}/assets/index.html")
}
resource "aws_dynamodb_table" "bookings" {
  name                        = "unicorn-concert-db"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "booking_id"
  deletion_protection_enabled = true
  attribute {
    name = "booking_id"
    type = "S"
  }
  attribute {
    name = "client_id"
    type = "S"
  }
  attribute {
    name = "created_at"
    type = "S"
  }
  global_secondary_index {
    name            = "client-id-created-at-index"
    hash_key        = "client_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }
}
resource "aws_ecr_repository" "app" {
  name                 = "unicorn-concert-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.data.arn
  }
}
resource "aws_iam_role" "cluster" {
  name = "unicorn-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "eks.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_security_group" "cluster" {
  name   = "unicorn-eks-cluster-sg"
  vpc_id = aws_vpc.this.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_eks_cluster" "this" {
  name                      = "unicorn-eks-cluster"
  version                   = "1.35"
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }
  encryption_config {
    provider {
      key_arn = aws_kms_key.platform.arn
    }
    resources = ["secrets"]
  }
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
resource "aws_iam_role" "node" {
  name = "unicorn-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}
resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "unicorn-app-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["t3.medium"]
  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 4
  }
  labels = {
    unicorn = "app"
  }
  tags = {
    Name = "unicorn-k8snode-app-node"
  }
  depends_on = [aws_iam_role_policy_attachment.node]
}
resource "aws_eks_node_group" "addon" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "unicorn-addon-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["t3.medium"]
  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 2
  }
  labels = {
    unicorn = "addon"
  }
  tags = {
    Name = "unicorn-k8snode-addon-node"
  }
  depends_on = [aws_iam_role_policy_attachment.node]
}
resource "aws_iam_role" "pod" {
  name = "unicorn-book-app-pod-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "pods.eks.amazonaws.com"
        }, Action = ["sts:AssumeRole", "sts:TagSession"], Condition = {
        StringEquals = {
          "aws:RequestTag/eks-cluster-name" = aws_eks_cluster.this.name
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "pod" {
  role = aws_iam_role.pod.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"], Resource = [aws_dynamodb_table.bookings.arn, "${aws_dynamodb_table.bookings.arn}/index/*"]
    }]
  })
}
resource "aws_eks_pod_identity_association" "book" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "unicorn"
  service_account = "unicorn-book-app"
  role_arn        = aws_iam_role.pod.arn
}
resource "kubernetes_namespace" "unicorn" {
  metadata {
    name = "unicorn"
  }
  depends_on = [aws_eks_node_group.app]
}
resource "kubernetes_service_account" "book" {
  metadata {
    name      = "unicorn-book-app"
    namespace = "unicorn"
  }
  depends_on = [kubernetes_namespace.unicorn]
}
resource "kubernetes_deployment" "book" {
  metadata {
    name      = "unicorn-book-app-deploy"
    namespace = "unicorn"
    labels = {
      app = "book"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "book"
      }
    }
    template {
      metadata {
        labels = {
          app = "book"
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
          image = var.book_image
          port {
            container_port = 8080
          }
          env {
            name  = "AWS_REGION"
            value = "ap-northeast-2"
          }
          env {
            name  = "TABLE_NAME"
            value = aws_dynamodb_table.bookings.name
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
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
  depends_on = [kubernetes_service_account.book]
}
resource "kubernetes_service" "book" {
  metadata {
    name      = "unicorn-book-app-svc"
    namespace = "unicorn"
  }
  spec {
    selector = {
      app = "book"
    }
    type = "NodePort"
    port {
      port        = 80
      target_port = 8080
      node_port   = 30080
    }
  }
  depends_on = [kubernetes_deployment.book]
}
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/unicorn/lambda/get-booking"
  kms_key_id        = aws_kms_key.platform.arn
  retention_in_days = 30
}
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/assets/get_booking.py"
  output_path = "${path.module}/get_booking.zip"
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
      Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query"], Resource = [aws_dynamodb_table.bookings.arn, "${aws_dynamodb_table.bookings.arn}/index/*"]
      }, {
      Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
    }]
  })
}
resource "aws_lambda_function" "get_booking" {
  function_name    = "unicorn-get-booking-func"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "get_booking.handler"
  runtime          = "python3.13"
  kms_key_arn      = aws_kms_key.app.arn
  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda.name
    log_format = "JSON"
  }
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.bookings.name
    }
  }
}
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_booking.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}
resource "aws_security_group" "alb" {
  name   = "unicorn-alb-sg"
  vpc_id = aws_vpc.this.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
}
resource "aws_lb" "app" {
  name               = "unicorn-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.private[*].id
}
resource "aws_lb_target_group" "app" {
  name     = "unicorn-tg"
  port     = 30080
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    path = "/health"
  }
}
resource "aws_lb_target_group" "lambda" {
  name        = "unicorn-lambda-tg"
  target_type = "lambda"
}
resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.get_booking.arn
  depends_on       = [aws_lambda_permission.alb]
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
resource "aws_lb_listener_rule" "get" {
  listener_arn = aws_lb_listener.http.arn
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
}
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "unicorn-web-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_vpc_origin" "alb" {
  vpc_origin_endpoint_config {
    name                   = "unicorn-alb-origin"
    arn                    = aws_lb.app.arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "unicorn-svc-cf"
  default_root_object = "index.html"
  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = "web"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }
  origin {
    domain_name = aws_lb.app.dns_name
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
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }
  ordered_cache_behavior {
    path_pattern           = "v1/*"
    target_origin_id       = "api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "413f1606-7674-4eed-a9e0-7b0c8b70cfe5"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  web_acl_id = aws_wafv2_web_acl.this.arn
}
resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "cloudfront.amazonaws.com"
        }, Action = "s3:GetObject", Resource = "${aws_s3_bucket.web.arn}/*", Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
        }
      }
    }]
  })
}
resource "aws_wafv2_web_acl" "this" {
  provider = aws.use1
  name     = "unicorn-waf"
  scope    = "CLOUDFRONT"
  default_action {
    allow {

    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "unicorn-waf"
    sampled_requests_enabled   = true
  }
  rule {
    name     = "AWSCommonRules"
    priority = 1
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
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "KnownBadInputs"
    priority = 2
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
      metric_name                = "bad-inputs"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "unicorn-rate-limit"
    priority = 3
    action {
      block {
        custom_response {
          custom_response_body_key = "blocked"
          response_code            = 403
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
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }
  custom_response_body {
    key          = "blocked"
    content_type = "APPLICATION_JSON"
    content      = "{\"message\":\"request blocked\"}"
  }
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
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query"], Resource = [aws_dynamodb_table.bookings.arn, "${aws_dynamodb_table.bookings.arn}/index/*"]
      }, {
      Effect = "Allow", Action = ["ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeRouteTables", "ec2:DescribeVpcEndpoints", "ec2:DescribeFlowLogs", "eks:DescribeCluster", "eks:ListNodegroups", "eks:DescribeNodegroup"], Resource = "*"
    }]
  })
}
variable "book_image" {
  type        = string
  description = "Immutable URI of the supplied book image"
}
variable "competitor_number" {
  type    = string
  default = "00007"
}
variable "audit_principal_arn" {
  type        = string
  description = "Trusted judge IAM principal ARN"
}
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.this.domain_name
}
output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
