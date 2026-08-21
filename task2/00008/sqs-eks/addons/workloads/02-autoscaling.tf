resource "kubernetes_manifest" "trigger_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata   = { name = "sqs-worker-trigger-auth", namespace = kubernetes_namespace_v1.worker.metadata[0].name }
    spec = {
      podIdentity = {
        provider = "aws-eks"
      }
    }
  }
}

resource "kubernetes_manifest" "scaled_object" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata   = { name = "sqs-worker-scaledobject", namespace = kubernetes_namespace_v1.worker.metadata[0].name }
    spec = {
      scaleTargetRef  = { name = kubernetes_deployment_v1.worker.metadata[0].name }
      minReplicaCount = 0
      maxReplicaCount = 6
      pollingInterval = 10
      cooldownPeriod  = 30
      triggers = [{
        type = "aws-sqs-queue"
        metadata = {
          queueURL    = local.input.queue_url
          queueLength = "2"
          awsRegion   = "us-west-2"
        }
        authenticationRef = { name = kubernetes_manifest.trigger_auth.manifest.metadata.name }
      }]
    }
  }
}
