data "aws_eks_cluster_auth" "main" {
  name = var.eks_cluster_name
}
