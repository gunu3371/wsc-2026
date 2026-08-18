resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = "observability"
  }
}

resource "helm_release" "prometheus" {

  name       = "wsc2026-prometheus"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "79.8.2"
  timeout    = 1200
  values = [yamlencode({

    prometheus = {
      prometheusSpec = {
        retention = "7d", nodeSelector = {
          "wsc2026/node" = "addon"
          }, additionalScrapeConfigs = [{
            job_name = "wsc2026-book", kubernetes_sd_configs = [{
              role = "pod"
              }], relabel_configs = [{
              source_labels = ["__meta_kubernetes_namespace"], regex = "wsc2026", action = "keep"
            }]
        }]
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        nodeSelector = {
          "wsc2026/node" = "addon"
        }
      }
    }
    grafana = {
      adminPassword = "Skills$#$@!", service = {
        type = "LoadBalancer"
        }, nodeSelector = {
        "wsc2026/node" = "addon"
        }, additionalDataSources = [{
          name      = "cloudwatch"
          uid       = "cloudwatch"
          type      = "cloudwatch"
          access    = "proxy"
          isDefault = false
          editable  = true
          jsonData = {
            authType      = "default"
            defaultRegion = var.region
          }
        }], sidecar = {
        dashboards = {
          enabled = true
          label   = "grafana_dashboard"
        }
      }
    }
    prometheusOperator = {
      nodeSelector = {
        "wsc2026/node" = "addon"
      }
    }
    kube-state-metrics = {
      nodeSelector = {
        "wsc2026/node" = "addon"
      }
    }

  })]

}

resource "helm_release" "fluent_bit" {

  name       = "wsc2026-fluent-bit"
  namespace  = kubernetes_namespace_v1.observability.metadata[0].name
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.49.1"
  values = [yamlencode({
    config = {

      filters = <<-EOT
      [FILTER]
          Name kubernetes
          Match kube.*
          Merge_Log On
      [FILTER]
          Name grep
          Match kube.*
          Exclude log ^.*(/health|health).*$
    EOT
      outputs = <<-EOT
      [OUTPUT]
          Name cloudwatch_logs
          Match kube.*
          region ${
      var.region
    }
          log_group_name /wsc2026/book
          log_stream_prefix fluent-bit-
          auto_create_group true
    EOT

    }
})]

}

resource "kubernetes_config_map_v1" "dashboard" {

  metadata {
    name      = "wsc2026-grafana-dashboard"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "wsc2026-grafana-dashboard.json" = templatefile("${path.module}/../assets/addons/dashboard.json.tftpl", {
      account_id = data.aws_caller_identity.current.account_id
      partition  = data.aws_partition.current.partition
      region     = var.region
    })
  }

}

resource "kubernetes_manifest" "alerts" {
  manifest   = yamldecode(file("${path.module}/../assets/addons/alerts.yaml"))
  depends_on = [helm_release.prometheus]

}
