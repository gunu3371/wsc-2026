data "aws_eks_cluster" "this" {
  name = local.input.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.aws_eks_cluster.this.name
}
