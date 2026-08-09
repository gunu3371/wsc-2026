resource "kubernetes_namespace_v1" "app" { metadata { name = "wskorea26" } }
resource "kubernetes_deployment_v1" "book" {
  metadata { name = "wskorea26-book"
namespace = kubernetes_namespace_v1.app.metadata[0].name }
  spec {
    replicas = 2
    selector { match_labels = { app = "book" } }
    template {
      metadata { labels = { app = "book" } }
      spec {
        node_selector = { "node-type" = "app" }
        container {
          name = "book"
image = var.book_image_uri
          port { container_port = 8080 }
          env { name = "TABLE_NAME"
value = data.terraform_remote_state.infra.outputs.dynamodb_table_name }
          resources { requests = { cpu = "100m", memory = "128Mi" }
limits = { cpu = "500m", memory = "512Mi" } }
        }
      }
    }
  }
}
resource "kubernetes_service_v1" "book" {
  metadata { name = "wskorea26-book"
namespace = kubernetes_namespace_v1.app.metadata[0].name }
  spec { selector = { app = "book" }
type = "NodePort"
port { port = 80
target_port = 8080
node_port = 30080 } }
}
resource "helm_release" "monitoring" {
  name = "wskorea26-monitoring"
namespace = "monitoring"
create_namespace = true
  repository = "https://prometheus-community.github.io/helm-charts"
chart = "kube-prometheus-stack"
  values = [yamlencode({
    prometheusOperator = { nodeSelector = { "node-type" = "addon" } }
    prometheus = { prometheusSpec = { nodeSelector = { "node-type" = "addon" } } }
    grafana = {
      adminUser = "skills-${var.candidate_id}-admin"
adminPassword = var.grafana_admin_password
      nodeSelector = { "node-type" = "addon" }
service = { type = "NodePort", nodePort = 30030 }
      dashboardProviders = { "dashboardproviders.yaml" = { apiVersion = 1, providers = [{ name = "default", orgId = 1, folder = "", type = "file", options = { path = "/var/lib/grafana/dashboards/default" } }] } }
      dashboards = { default = { wskorea26 = { json = file("${path.module}/../monitoring/dashboard.json") } } }
    }
  })]
}
