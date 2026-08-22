data "aws_iam_policy_document" "grafana_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")}:sub"
      values   = ["system:serviceaccount:observability:wsc2026-prometheus-grafana"]
    }
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana_cloudwatch" {
  name               = "wsc2026-grafana-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name = "wsc2026-grafana-cloudwatch-read"
  role = aws_iam_role.grafana_cloudwatch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:DescribeLogGroups",
        "logs:GetLogEvents",
        "logs:FilterLogEvents",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "ec2:DescribeRegions",
        "tag:GetResources",
      ]
      Resource = "*"
    }]
  })
}

locals {
  fluent_bit_metrics_config = <<-EOT
    [SERVICE]
        Daemon Off
        Flush 1
        Log_Level info
        Parsers_File /fluent-bit/etc/parsers.conf
        Parsers_File /fluent-bit/etc/conf/custom_parsers.conf
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port 2020
        Health_Check On

    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        multiline.parser docker, cri
        Tag kube.*
        Mem_Buf_Limit 5MB
        Skip_Long_Lines On

    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On

    [FILTER]
        Name grep
        Match kube.*
        Exclude log ^.*(/health|health).*$

    [FILTER]
        Name lua
        Match kube.*
        script /fluent-bit/etc/conf/duration.lua
        call normalize_http_duration

    [FILTER]
        Name log_to_metrics
        Match kube.*
        Tag wsc2026.metrics.requests
        Metric_Mode counter
        Metric_Name http_requests_total
        Metric_Description Total HTTP requests derived from application logs
        Regex $kubernetes['namespace_name'] ^wsc2026$
        Regex status ^[1-5][0-9][0-9]$
        Label_Field status

    [FILTER]
        Name log_to_metrics
        Match kube.*
        Tag wsc2026.metrics.duration
        Metric_Mode histogram
        Metric_Name http_request_duration_seconds
        Metric_Description HTTP request duration derived from application logs
        Value_Field duration_seconds
        Regex $kubernetes['namespace_name'] ^wsc2026$
        Regex duration_seconds ^[0-9]
        Label_Field status
        Bucket 0.1
        Bucket 0.25
        Bucket 0.5
        Bucket 1
        Bucket 2.5
        Bucket 3
        Bucket 5
        Bucket 10

    [OUTPUT]
        Name cloudwatch_logs
        Match kube.*
        region ${local.input.region}
        log_group_name /wsc2026/book
        log_stream_prefix fluent-bit-
        auto_create_group true

    [OUTPUT]
        Name prometheus_exporter
        Match wsc2026.metrics.*
        Host 0.0.0.0
        Port 2021
  EOT
}

resource "kubernetes_config_map_v1_data" "fluent_bit_metrics" {
  metadata {
    name      = "wsc2026-fluent-bit"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }
  data = {
    "fluent-bit.conf" = local.fluent_bit_metrics_config
    "duration.lua"    = file("${path.module}/../assets/addons/duration.lua")
  }
  field_manager = "terraform-wsc2026-observability"
  force         = true
  depends_on    = [helm_release.fluent_bit]
}

resource "kubernetes_annotations" "fluent_bit_rollout" {
  api_version = "apps/v1"
  kind        = "DaemonSet"
  metadata {
    name      = "wsc2026-fluent-bit"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }
  template_annotations = {
    "wsc2026/log-metrics-config" = sha256(join("", [local.fluent_bit_metrics_config, file("${path.module}/../assets/addons/duration.lua")]))
  }
  field_manager = "terraform-wsc2026-observability"
  force         = true
  depends_on    = [kubernetes_config_map_v1_data.fluent_bit_metrics]
}

resource "kubernetes_service_v1" "fluent_bit_metrics" {
  metadata {
    name      = "wsc2026-fluent-bit-metrics"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels = {
      "wsc2026/metrics" = "fluent-bit"
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "wsc2026-fluent-bit"
      "app.kubernetes.io/name"     = "fluent-bit"
    }
    port {
      name        = "metrics"
      port        = 2021
      target_port = 2021
    }
  }
}

resource "kubernetes_manifest" "fluent_bit_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "wsc2026-fluent-bit-metrics"
      namespace = kubernetes_namespace_v1.observability.metadata[0].name
      labels = {
        release = "wsc2026-prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "wsc2026/metrics" = "fluent-bit"
        }
      }
      endpoints = [{
        port     = "metrics"
        path     = "/metrics"
        interval = "15s"
      }]
    }
  }
  depends_on = [kubernetes_service_v1.fluent_bit_metrics]
}
