resource "helm_release" "monitoring" {
  name             = "wskorea26-monitoring"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  values = [yamlencode({
    prometheusOperator = {
      nodeSelector = {
        "node-type" = "addon"
        }, tolerations = [{
          key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
      }]
      admissionWebhooks = {
        patch = {
          nodeSelector = {
            "node-type" = "addon"
            }, tolerations = [{
              key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
          }]
        }
      }
    }
    prometheus = {
      prometheusSpec = {
        nodeSelector = {
          "node-type" = "addon"
          }, tolerations = [{
            key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
        }]
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        nodeSelector = {
          "node-type" = "addon"
          }, tolerations = [{
            key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
        }]
      }
    }
    "kube-state-metrics" = {
      nodeSelector = {
        "node-type" = "addon"
        }, tolerations = [{
          key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
      }]
    }
    "prometheus-node-exporter" = {
      tolerations = [{
        key = "node-type", operator = "Exists", effect = "NoSchedule"
      }]
    }
    grafana = {
      adminUser     = "skills-${var.task_id}-admin"
      adminPassword = var.grafana_admin_password
      nodeSelector = {
        "node-type" = "addon"
      }
      tolerations = [{
        key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
      }]
      service = {
        type = "NodePort", nodePort = 30030
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1, providers = [{
            name = "default", orgId = 1, folder = "", type = "file", options = {
              path = "/var/lib/grafana/dashboards/default"
            }
          }]
        }
      }
      dashboards = {
        default = {
          wskorea26 = {
            json = file("${path.module}/../assets/foundation/monitoring/dashboard.json")
          }
        }
      }
    }
  })]
}
