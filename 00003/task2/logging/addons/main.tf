resource "kubernetes_namespace_v1" "app" { metadata { name = "wsc2026-app" } }
resource "kubernetes_namespace_v1" "logging" { metadata { name = "wsc2026-logging" } }
resource "kubernetes_config_map_v1" "log_generator" {
  metadata {
    name      = "log-generator"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  data = { "log-generator.py" = file("${path.module}/log-generator.py") }
}
resource "kubernetes_deployment_v1" "app" { metadata { name = "log-generator"
namespace = kubernetes_namespace_v1.app.metadata[0].name
labels = { app = "log-generator" } }
spec { replicas = 1
selector { match_labels = { app = "log-generator" } }
template { metadata { labels = { app = "log-generator" } }
spec { container { name = "log-generator"
image = var.log_generator_image
command = ["python", "/app/log-generator.py"]
port { container_port = 8080 }
readiness_probe { http_get { path = "/health"
port = 8080 } }
volume_mount { name = "source"
mount_path = "/app"
read_only = true } }
volume { name = "source"
config_map { name = kubernetes_config_map_v1.log_generator.metadata[0].name } } } } } }
resource "kubernetes_service_v1" "app" { metadata { name = "log-generator"
namespace = kubernetes_namespace_v1.app.metadata[0].name }
spec { type = "LoadBalancer"
selector = { app = "log-generator" }
port { port = 80
target_port = 8080 } } }

resource "helm_release" "loki" { name = "wsc2026-loki"
namespace = kubernetes_namespace_v1.logging.metadata[0].name
repository = "https://grafana.github.io/helm-charts"
chart = "loki"
version = "6.49.0"
timeout = 1200
values = [yamlencode({ deploymentMode = "SingleBinary", loki = { auth_enabled = false, commonConfig = { replication_factor = 1 }, storage = { type = "filesystem" }, schemaConfig = { configs = [{ from = "2024-01-01", store = "tsdb", object_store = "filesystem", schema = "v13", index = { prefix = "index_", period = "24h" } }] } }, singleBinary = { replicas = 1 }, backend = { replicas = 0 }, read = { replicas = 0 }, write = { replicas = 0 }, gateway = { enabled = false }, chunksCache = { enabled = false }, resultsCache = { enabled = false } })] }

resource "helm_release" "otel" { name = "wsc2026-otel-collector"
namespace = kubernetes_namespace_v1.logging.metadata[0].name
repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
chart = "opentelemetry-collector"
version = "0.136.0"
values = [file("${path.module}/assets/otel-values.yaml")]
depends_on = [helm_release.loki] }
resource "helm_release" "fluent_bit" { name = "wsc2026-fluent-bit"
namespace = kubernetes_namespace_v1.logging.metadata[0].name
repository = "https://fluent.github.io/helm-charts"
chart = "fluent-bit"
version = "0.49.1"
values = [file("${path.module}/assets/fluent-bit-values.yaml")]
depends_on = [helm_release.otel] }
resource "helm_release" "prometheus" { name = "wsc2026-prometheus-server"
namespace = kubernetes_namespace_v1.logging.metadata[0].name
repository = "https://prometheus-community.github.io/helm-charts"
chart = "prometheus"
version = "27.39.0"
values = [yamlencode({ server = { fullnameOverride = "wsc2026-prometheus-server", extraScrapeConfigs = <<-EOT
    - job_name: otel-collector
      static_configs:
        - targets: ['wsc2026-otel-collector-opentelemetry-collector:8889']
    EOT
  }, alertmanager = { enabled = false }, "prometheus-node-exporter" = { enabled = false }, "kube-state-metrics" = { enabled = false }, "prometheus-pushgateway" = { enabled = false } })] }
resource "helm_release" "grafana" { name = "wsc2026-grafana"
namespace = kubernetes_namespace_v1.logging.metadata[0].name
repository = "https://grafana.github.io/helm-charts"
chart = "grafana"
version = "10.0.0"
values = [yamlencode({ fullnameOverride = "wsc2026-grafana", adminPassword = "Skill53@@", service = { type = "LoadBalancer" }, datasources = { "datasources.yaml" = { apiVersion = 1, datasources = [{ name = "Loki", type = "loki", access = "proxy", url = "http://wsc2026-loki.wsc2026-logging.svc.cluster.local:3100" }, { name = "Prometheus", type = "prometheus", access = "proxy", url = "http://wsc2026-prometheus-server.wsc2026-logging.svc.cluster.local" }] } }, dashboardProviders = { "dashboardproviders.yaml" = { apiVersion = 1, providers = [{ name = "default", orgId = 1, folder = "", type = "file", disableDeletion = false, editable = true, options = { path = "/var/lib/grafana/dashboards/default" } }] } }, dashboardsConfigMaps = { default = kubernetes_config_map_v1.dashboard.metadata[0].name } })]
depends_on = [helm_release.prometheus, helm_release.loki] }
resource "kubernetes_config_map_v1" "dashboard" { metadata { name = "wsc2026-app-logs"
namespace = kubernetes_namespace_v1.logging.metadata[0].name }
data = { "wsc2026-app-logs.json" = file("${path.module}/assets/dashboard.json") } }
