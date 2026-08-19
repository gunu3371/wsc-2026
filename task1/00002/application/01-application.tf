resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = "wskorea26"
  }
}
resource "kubernetes_deployment_v1" "book" {
  metadata {
    name      = "wskorea26-book"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "book"
      }
    }
    template {
      metadata {
        labels = {
          app = "book"
        }
      }
      spec {
        node_selector = {
          "node-type" = "app"
        }
        toleration {
          key      = "node-type"
          operator = "Equal"
          value    = "app"
          effect   = "NoSchedule"
        }
        container {
          name  = "book"
          image = local.input.book_image_uri
          port {
            container_port = 8080
          }
          env {
            name  = "TABLE_NAME"
            value = local.input.dynamodb_table_name
          }
          resources {
            requests = {
              cpu = "100m", memory = "128Mi"
            }
            limits = {
              cpu = "500m", memory = "512Mi"
            }
          }
        }
      }
    }
  }
}
resource "kubernetes_service_v1" "book" {
  metadata {
    name      = "wskorea26-book"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  spec {
    selector = {
      app = "book"
    }
    type = "NodePort"
    port {
      port        = 80
      target_port = 8080
      node_port   = 30080
    }
  }
}
