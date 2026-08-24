resource "kubernetes_namespace_v1" "main" {
  metadata {
    name = "apdev"
    labels = {
      "app.kubernetes.io/part-of" = local.input.project_name
    }
  }
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${local.input.project_name}-load-balancer-controller"
  policy = file("${path.module}/../assets/application/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${local.input.project_name}-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "kubernetes_service_account_v1" "load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = local.input.cluster_name
  namespace       = kubernetes_service_account_v1.load_balancer_controller.metadata[0].namespace
  service_account = kubernetes_service_account_v1.load_balancer_controller.metadata[0].name
  role_arn        = aws_iam_role.load_balancer_controller.arn

  depends_on = [aws_iam_role_policy_attachment.load_balancer_controller]
}

resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = local.input.aws_load_balancer_chart_version

  wait    = true
  timeout = 900

  values = [yamlencode({
    clusterName                 = local.input.cluster_name
    region                      = local.input.aws_region
    vpcId                       = local.input.vpc_id
    replicaCount                = 2
    enableServiceMutatorWebhook = false
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.load_balancer_controller.metadata[0].name
    }
    nodeSelector = { workload = "core" }
    resources = {
      requests = { cpu = "50m", memory = "100Mi" }
      limits   = { cpu = "200m", memory = "256Mi" }
    }
  })]

  depends_on = [aws_eks_pod_identity_association.load_balancer_controller]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"

  wait    = true
  timeout = 600

  values = [yamlencode({
    nodeSelector = { workload = "core" }
    resources = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits   = { cpu = "200m", memory = "192Mi" }
    }
  })]
}
