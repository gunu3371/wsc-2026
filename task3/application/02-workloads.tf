resource "kubernetes_secret_v1" "database" {
  metadata {
    name      = "database"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  data = {
    MYSQL_USER     = local.db.username
    MYSQL_PASSWORD = local.db.password
    MYSQL_HOST     = local.db.host
    MYSQL_PORT     = tostring(local.db.port)
    MYSQL_DBNAME   = local.db.dbname
  }

  type = "Opaque"
}

resource "kubernetes_service_account_v1" "product" {
  metadata {
    name      = "product"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }
}

resource "aws_eks_pod_identity_association" "product" {
  cluster_name    = local.input.cluster_name
  namespace       = kubernetes_namespace_v1.main.metadata[0].name
  service_account = kubernetes_service_account_v1.product.metadata[0].name
  role_arn        = local.input.product_pod_role_arn
}

resource "kubernetes_deployment_v1" "application" {
  for_each = local.app_ports

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    labels    = { app = each.key }
  }

  spec {
    replicas = local.input.replicas

    selector { match_labels = { app = each.key } }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "50%"
        max_unavailable = "0"
      }
    }

    template {
      metadata { labels = { app = each.key } }
      spec {
        service_account_name = each.key == "product" ? kubernetes_service_account_v1.product.metadata[0].name : "default"

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector { match_labels = { app = each.key } }
        }

        container {
          name              = each.key
          image             = local.app_images[each.key]
          image_pull_policy = "Always"

          port { container_port = each.value }

          dynamic "env" {
            for_each = each.key == "stress" ? [] : ["MYSQL_USER", "MYSQL_PASSWORD", "MYSQL_HOST", "MYSQL_PORT", "MYSQL_DBNAME"]
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.database.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          dynamic "env" {
            for_each = each.key == "product" ? {
              AWS_REGION         = local.input.aws_region
              AWS_DEFAULT_REGION = local.input.aws_region
              S3_BUCKET          = local.input.image_bucket_name
              S3_BUCKET_NAME     = local.input.image_bucket_name
            } : {}
            content {
              name  = env.key
              value = env.value
            }
          }

          readiness_probe {
            http_get {
              path = "/healthcheck"
              port = each.value
            }
            initial_delay_seconds = 3
            period_seconds        = 5
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/healthcheck"
              port = each.value
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "750m", memory = "512Mi" }
          }
        }

        termination_grace_period_seconds = 30
      }
    }
  }

  lifecycle {
    ignore_changes = [spec[0].replicas]
  }

  depends_on = [aws_eks_pod_identity_association.product]
}

resource "kubernetes_service_v1" "application" {
  for_each = local.app_ports

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  spec {
    selector = { app = each.key }
    port {
      port        = 80
      target_port = each.value
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "application" {
  for_each = local.app_ports

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 6

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.application[each.key].metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 60
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        select_policy                = "Max"
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 15
        }
        policy {
          type           = "Pods"
          value          = 2
          period_seconds = 15
        }
      }
      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Max"
        policy {
          type           = "Percent"
          value          = 25
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [helm_release.metrics_server]
}

resource "kubernetes_pod_disruption_budget_v1" "application" {
  for_each = local.app_ports

  metadata {
    name      = each.key
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  spec {
    max_unavailable = "1"
    selector { match_labels = { app = each.key } }
  }
}
