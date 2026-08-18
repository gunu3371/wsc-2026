resource "kubernetes_namespace_v1" "worker" {
  metadata {
    name = "skills-sqs"
  }
}

resource "kubernetes_service_account_v1" "worker" {
  metadata {
    name      = "sqs-worker-sa"
    namespace = kubernetes_namespace_v1.worker.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.worker_role_arn
    }
  }
}

resource "kubernetes_deployment_v1" "worker" {
  metadata {
    name      = "sqs-worker"
    namespace = kubernetes_namespace_v1.worker.metadata[0].name
    labels    = { app = "sqs-worker" }
  }

  spec {
    replicas = 0
    selector {
      match_labels = { app = "sqs-worker" }
    }
    template {
      metadata {
        labels = { app = "sqs-worker" }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.worker.metadata[0].name
        node_selector = {
          "karpenter.sh/nodepool" = "skills-sqs-nodepool"
          "skills-nodepool"       = "event-worker"
        }
        container {
          name  = "worker"
          image = coalesce(var.worker_image, "${var.worker_repository_url}:latest")
          env {
            name  = "SQS_QUEUE_URL"
            value = var.queue_url
          }
          env {
            name  = "AWS_REGION"
            value = "us-west-2"
          }
          env {
            name  = "PROCESSING_SECONDS"
            value = "5"
          }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "256Mi" }
          }
        }
      }
    }
  }
}
