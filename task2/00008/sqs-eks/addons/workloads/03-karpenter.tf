resource "kubernetes_manifest" "node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "skills-sqs-nodeclass" }
    spec = {
      role             = var.node_role_name
      amiSelectorTerms = [{ alias = "al2023@latest" }]
      subnetSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery"          = data.aws_eks_cluster.this.name
          "kubernetes.io/role/internal-elb" = "1"
        }
      }]
      securityGroupSelectorTerms = [{ tags = { "karpenter.sh/discovery" = data.aws_eks_cluster.this.name } }]
      metadataOptions            = { httpEndpoint = "enabled", httpProtocolIPv6 = "disabled", httpPutResponseHopLimit = 2, httpTokens = "required" }
      blockDeviceMappings        = [{ deviceName = "/dev/xvda", ebs = { volumeSize = "20Gi", volumeType = "gp3", encrypted = true, deleteOnTermination = true } }]
      tags                       = { Name = "skills-sqs-worker", "karpenter.sh/discovery" = data.aws_eks_cluster.this.name }
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
