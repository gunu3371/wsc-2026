resource "kubernetes_deployment_v1" "workload" {
  for_each = local.input.additional_workloads

  metadata {
    name      = each.key
    namespace = local.namespace
    labels    = { app = each.key }
  }

  spec {
    replicas = each.value.replicas

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
        node_selector = { workload = each.key }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = each.key
          effect   = "NoSchedule"
        }

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector { match_labels = { app = each.key } }
        }

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector { match_labels = { app = each.key } }
        }

        container {
          name              = each.key
          image             = "${local.input.ecr_repository_urls[each.key]}:${each.value.image_tag}"
          image_pull_policy = "Always"

          port { container_port = each.value.container_port }

          dynamic "env" {
            for_each = each.value.use_database ? ["MYSQL_USER", "MYSQL_PASSWORD", "MYSQL_HOST", "MYSQL_PORT", "MYSQL_DBNAME"] : []
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = "database"
                  key  = env.value
                }
              }
            }
          }

          dynamic "env" {
            for_each = each.value.environment
            content {
              name  = env.key
              value = env.value
            }
          }

          readiness_probe {
            http_get {
              path = each.value.healthcheck_path
              port = each.value.container_port
            }
            initial_delay_seconds = 3
            period_seconds        = 5
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = each.value.healthcheck_path
              port = each.value.container_port
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = each.value.resources.requests.cpu
              memory = each.value.resources.requests.memory
            }
            limits = {
              cpu    = each.value.resources.limits.cpu
              memory = each.value.resources.limits.memory
            }
          }
        }

        termination_grace_period_seconds = 30
      }
    }
  }

  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_service_v1" "workload" {
  for_each = local.input.additional_workloads

  metadata {
    name      = each.key
    namespace = local.namespace
  }

  spec {
    selector = { app = each.key }
    port {
      port        = 80
      target_port = each.value.container_port
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "workload" {
  for_each = local.input.additional_workloads

  metadata {
    name      = each.key
    namespace = local.namespace
  }

  spec {
    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.workload[each.key].metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = each.value.hpa_cpu_percent
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
}

resource "kubernetes_pod_disruption_budget_v1" "workload" {
  for_each = local.input.additional_workloads

  metadata {
    name      = each.key
    namespace = local.namespace
  }

  spec {
    max_unavailable = "1"
    selector { match_labels = { app = each.key } }
  }
}
