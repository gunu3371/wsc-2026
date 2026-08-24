resource "kubernetes_ingress_v1" "workload" {
  for_each = local.input.additional_workloads

  metadata {
    name      = each.key
    namespace = local.namespace
    annotations = {
      "alb.ingress.kubernetes.io/group.name"           = local.alb_group_name
      "alb.ingress.kubernetes.io/group.order"          = tostring(local.workload_orders[each.key])
      "alb.ingress.kubernetes.io/healthcheck-path"     = each.value.healthcheck_path
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = each.value.route_path
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.workload[each.key].metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
