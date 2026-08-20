data "aws_eks_cluster_auth" "main" {
  name = local.input.eks_cluster_name
}

data "aws_ecr_repository" "book" {
  name = "wskorea26-book-repo"
}
