terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
}
provider "aws" { region = "us-west-2" }
data "terraform_remote_state" "infra" {
  backend = "local"
  config  = { path = "../../infra/terraform.tfstate" }
}
data "aws_eks_cluster" "this" { name = data.terraform_remote_state.infra.outputs.cluster_name }
data "aws_eks_cluster_auth" "this" { name = data.aws_eks_cluster.this.name }
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
resource "kubernetes_namespace_v1" "worker" { metadata { name = "skills-sqs" } }
resource "kubernetes_service_account_v1" "worker" {
  metadata {
    name      = "sqs-worker-sa"
    namespace = kubernetes_namespace_v1.worker.metadata[0].name
    annotations = { "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infra.outputs.worker_role_arn }
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
    selector { match_labels = { app = "sqs-worker" } }
    template {
      metadata { labels = { app = "sqs-worker" } }
      spec {
        service_account_name = kubernetes_service_account_v1.worker.metadata[0].name
        node_selector = {
          "karpenter.sh/nodepool" = "skills-sqs-nodepool"
          "skills-nodepool"       = "event-worker"
        }
        container {
          name  = "worker"
          image = coalesce(var.worker_image, "${data.terraform_remote_state.infra.outputs.worker_repository_url}:latest")
          env {
            name  = "SQS_QUEUE_URL"
            value = data.terraform_remote_state.infra.outputs.queue_url
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
resource "kubernetes_manifest" "trigger_auth" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata   = { name = "sqs-worker-trigger-auth", namespace = kubernetes_namespace_v1.worker.metadata[0].name }
    spec       = { podIdentity = { provider = "aws-eks" } }
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
          queueURL    = data.terraform_remote_state.infra.outputs.queue_url
          queueLength = "2"
          awsRegion   = "us-west-2"
        }
        authenticationRef = { name = kubernetes_manifest.trigger_auth.manifest.metadata.name }
      }]
    }
  }
}
resource "kubernetes_manifest" "node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "skills-sqs-nodeclass" }
    spec = {
      role = data.terraform_remote_state.infra.outputs.node_role_name
      amiSelectorTerms = [{ alias = "al2023@latest" }]
      subnetSelectorTerms = [{ tags = { "karpenter.sh/discovery" = data.aws_eks_cluster.this.name } }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = data.aws_eks_cluster.this.name } }]
      metadataOptions = { httpEndpoint = "enabled", httpProtocolIPv6 = "disabled", httpPutResponseHopLimit = 2, httpTokens = "required" }
      blockDeviceMappings = [{ deviceName = "/dev/xvda", ebs = { volumeSize = "20Gi", volumeType = "gp3", encrypted = true, deleteOnTermination = true } }]
      tags = { Name = "skills-sqs-worker", "karpenter.sh/discovery" = data.aws_eks_cluster.this.name }
    }
  }
}
resource "kubernetes_manifest" "node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "skills-sqs-nodepool" }
    spec = {
      template = {
        metadata = { labels = { "skills-nodepool" = "event-worker" } }
        spec = {
          nodeClassRef = { group = "karpenter.k8s.aws", kind = "EC2NodeClass", name = kubernetes_manifest.node_class.manifest.metadata.name }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            { key = "node.kubernetes.io/instance-type", operator = "In", values = ["t3.small", "t3.medium", "m5.large"] }
          ]
        }
      }
      limits     = { cpu = "20", memory = "40Gi" }
      disruption = { consolidationPolicy = "WhenEmptyOrUnderutilized", consolidateAfter = "30s" }
    }
  }
}
variable "worker_image" {
  type    = string
  default = null
}
