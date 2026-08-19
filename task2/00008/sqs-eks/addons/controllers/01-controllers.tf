resource "kubernetes_namespace_v1" "keda" {
  metadata {
    name = "keda"
  }
}

resource "kubernetes_namespace_v1" "karpenter" {
  metadata {
    name = "karpenter"
  }
}

resource "kubernetes_annotations" "coredns" {
  api_version = "apps/v1"
  kind        = "Deployment"

  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }

  annotations = {}
  template_annotations = {
    "eks.amazonaws.com/compute-type" = "fargate"
  }
  force = true
}

resource "helm_release" "keda" {
  name       = "keda"
  namespace  = kubernetes_namespace_v1.keda.metadata[0].name
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = local.input.keda_chart_version

  values = [yamlencode({
    serviceAccount = {
      operator = {
        create      = true
        name        = "keda-operator"
        annotations = { "eks.amazonaws.com/role-arn" = local.input.keda_role_arn }
      }
    }
    podLabels = { "eks.amazonaws.com/compute-type" = "fargate" }
  })]
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = kubernetes_namespace_v1.karpenter.metadata[0].name
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.input.karpenter_chart_version

  values = [yamlencode({
    serviceAccount = {
      create      = true
      name        = "karpenter"
      annotations = { "eks.amazonaws.com/role-arn" = local.input.karpenter_role_arn }
    }
    settings   = { clusterName = data.aws_eks_cluster.this.name }
    controller = { resources = { requests = { cpu = "250m", memory = "256Mi" }, limits = { cpu = "1", memory = "1Gi" } } }
  })]
}
