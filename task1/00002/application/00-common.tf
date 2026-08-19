data "aws_eks_cluster_auth" "main" {
  name = local.input.eks_cluster_name
}
