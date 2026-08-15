data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../foundation/terraform.tfstate"
  }
}

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.infra.outputs.eks_cluster_name
}
