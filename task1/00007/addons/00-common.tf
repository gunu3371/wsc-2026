data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "main" {
  name = local.input.cluster_name
}
