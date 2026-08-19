resource "kubernetes_annotations" "grafana_service_account" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name      = local.input.grafana_service_account
    namespace = local.input.namespace
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
    name      = local.input.grafana_deployment
    namespace = local.input.namespace
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
    namespace = local.input.namespace
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
          defaultRegion = local.input.region
        }
      }]
    })
  }
}

resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = "wsc2026-grafana-dashboard-v2"
    namespace = local.input.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "wsc2026-grafana-dashboard.json" = templatefile("${path.module}/../../assets/addons/dashboard.json.tftpl", {
      account_id = data.aws_caller_identity.current.account_id
      partition  = data.aws_partition.current.partition
      region     = local.input.region
    })
  }
}

locals {
  alerts = yamldecode(file("${path.module}/../../assets/addons/alerts.yaml"))
}

resource "kubernetes_manifest" "alerts" {
  manifest = merge(local.alerts, {
    metadata = merge(local.alerts.metadata, {
      name = "wsc2026-alerts-v2"
    })
  })
}
