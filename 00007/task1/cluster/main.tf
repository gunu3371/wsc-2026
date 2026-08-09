terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
}
provider "aws" { region = "ap-northeast-2" }
variable "foundation_state_path" { type = string
 default = "../foundation/terraform.tfstate" }
variable "kubernetes_version" { type = string
 default = "1.35" }
data "terraform_remote_state" "foundation" { backend = "local"
 config = { path = var.foundation_state_path } }
data "aws_partition" "current" {}

resource "aws_iam_role" "cluster" { name = "unicorn-eks-cluster-role"
 assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = ["sts:AssumeRole", "sts:TagSession"] }] }) }
resource "aws_iam_role_policy_attachment" "cluster" { role = aws_iam_role.cluster.name
 policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy" }
resource "aws_eks_cluster" "main" {
  name = "unicorn-eks-cluster"
 version = var.kubernetes_version
 role_arn = aws_iam_role.cluster.arn
  vpc_config { subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
 endpoint_public_access = false
 endpoint_private_access = true }
  access_config { authentication_mode = "API"
 bootstrap_cluster_creator_admin_permissions = true }
  encryption_config { provider { key_arn = data.terraform_remote_state.foundation.outputs.platform_kms_arn }
 resources = ["secrets"] }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
resource "aws_iam_role" "node" { name = "unicorn-eks-node-role"
 assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] }) }
resource "aws_iam_role_policy_attachment" "node" { for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
 role = aws_iam_role.node.name
 policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}" }
resource "aws_launch_template" "app" { name = "unicorn-app-node"
 tag_specifications { resource_type = "instance"
 tags = { Name = "unicorn-k8snode-app-node" } } }
resource "aws_launch_template" "addon" { name = "unicorn-addon-node"
 tag_specifications { resource_type = "instance"
 tags = { Name = "unicorn-k8snode-addon-node" } } }
resource "aws_eks_node_group" "app" { cluster_name = aws_eks_cluster.main.name
 node_group_name = "unicorn-app-ng"
 node_role_arn = aws_iam_role.node.arn
 subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
 instance_types = ["t3.medium"]
 scaling_config { min_size = 2
 desired_size = 3
 max_size = 6 }
 labels = { unicorn = "app", timezone = "Asia-Seoul" }
 launch_template { id = aws_launch_template.app.id
 version = aws_launch_template.app.latest_version }
 depends_on = [aws_iam_role_policy_attachment.node] }
resource "aws_eks_node_group" "addon" { cluster_name = aws_eks_cluster.main.name
 node_group_name = "unicorn-addon-ng"
 node_role_arn = aws_iam_role.node.arn
 subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
 instance_types = ["t3.medium"]
 scaling_config { min_size = 1
 desired_size = 1
 max_size = 3 }
 labels = { unicorn = "addon", timezone = "Asia-Seoul" }
 launch_template { id = aws_launch_template.addon.id
 version = aws_launch_template.addon.latest_version }
 depends_on = [aws_iam_role_policy_attachment.node] }
resource "aws_eks_addon" "pod_identity" { cluster_name = aws_eks_cluster.main.name
 addon_name = "eks-pod-identity-agent"
 depends_on = [aws_eks_node_group.app, aws_eks_node_group.addon] }
resource "aws_eks_addon" "ebs" { cluster_name = aws_eks_cluster.main.name
 addon_name = "aws-ebs-csi-driver"
 depends_on = [aws_eks_node_group.addon] }
output "cluster_name" { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_ca" { value = aws_eks_cluster.main.certificate_authority[0].data
 sensitive = true }
output "cluster_security_group_id" { value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id }
