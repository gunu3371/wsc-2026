locals {
  fluent_bit_config = <<-EOT
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

    [INPUT]
        Name systemd
        Tag host.*
        Systemd_Filter _SYSTEMD_UNIT=kubelet.service
        Read_From_Tail On

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
        region ${var.region}
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
    namespace = var.namespace
  }
  data = {
    "fluent-bit.conf" = local.fluent_bit_config
    "duration.lua"    = file("${path.module}/../../addons/assets/duration.lua")
  }
  field_manager = "terraform-observability-fix"
  force         = true
}

resource "kubernetes_annotations" "fluent_bit_rollout" {
  api_version = "apps/v1"
  kind        = "DaemonSet"
  metadata {
    name      = "wsc2026-fluent-bit"
    namespace = var.namespace
  }
  template_annotations = {
    "wsc2026/log-metrics-config" = sha256(join("", [local.fluent_bit_config, file("${path.module}/../../addons/assets/duration.lua")]))
  }
  field_manager = "terraform-observability-fix"
  force         = true
  depends_on    = [kubernetes_config_map_v1_data.fluent_bit_metrics]
}

resource "kubernetes_service_v1" "fluent_bit_metrics" {
  metadata {
    name      = "wsc2026-fluent-bit-metrics"
    namespace = var.namespace
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
      namespace = var.namespace
      labels = {
        release = "wsc2026-prometheus"
      }
    }
    spec = {
      attachMetadata = {
        node = true
      }
      namespaceSelector = {
        matchNames = [var.namespace]
      }
      selector = {
        matchLabels = {
          "wsc2026/metrics" = "fluent-bit"
        }
      }
      endpoints = [{
        port     = "metrics"
        path     = "/metrics"
        interval = "15s"
        relabelings = [{
          action       = "keep"
          regex        = "application"
          sourceLabels = ["__meta_kubernetes_node_label_wsc2026_node"]
        }]
      }]
    }
  }
  depends_on = [kubernetes_service_v1.fluent_bit_metrics]
}
