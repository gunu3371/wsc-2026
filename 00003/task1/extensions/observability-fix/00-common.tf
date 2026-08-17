data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  oidc_issuer = trimprefix(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")
}

data "aws_iam_openid_connect_provider" "eks" {
  arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer}"
}
