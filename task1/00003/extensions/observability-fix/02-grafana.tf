resource "kubernetes_annotations" "grafana_service_account" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name      = var.grafana_service_account
    namespace = var.namespace
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.grafana_cloudwatch.arn
  }
  field_manager = "terraform-observability-fix"
  force         = true
}

resource "kubernetes_annotations" "grafana_rollout" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = var.grafana_deployment
    namespace = var.namespace
  }
  template_annotations = {
    "wsc2026/grafana-cloudwatch-role-arn" = aws_iam_role.grafana_cloudwatch.arn
  }
  field_manager = "terraform-observability-fix"
  force         = true
  depends_on    = [kubernetes_annotations.grafana_service_account]
}

resource "kubernetes_config_map_v1" "cloudwatch_datasource" {
  metadata {
    name      = "wsc2026-grafana-cloudwatch-datasource"
    namespace = var.namespace
    labels = {
      grafana_datasource = "1"
    }
  }
  data = {
    "cloudwatch.yaml" = yamlencode({
      apiVersion = 1
      datasources = [{
        name      = "cloudwatch"
        uid       = "cloudwatch"
        type      = "cloudwatch"
        access    = "proxy"
        editable  = true
        isDefault = false
        jsonData = {
          authType      = "default"
          defaultRegion = var.region
        }
      }]
    })
  }
}

resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = "wsc2026-grafana-dashboard-v2"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "wsc2026-grafana-dashboard.json" = templatefile("${path.module}/../../addons/assets/dashboard.json.tftpl", {
      account_id = data.aws_caller_identity.current.account_id
      partition  = data.aws_partition.current.partition
      region     = var.region
    })
  }
}

locals {
  alerts = yamldecode(file("${path.module}/../../addons/assets/alerts.yaml"))
}

resource "kubernetes_manifest" "alerts" {
  manifest = merge(local.alerts, {
    metadata = merge(local.alerts.metadata, {
      name = "wsc2026-alerts-v2"
    })
  })
}
