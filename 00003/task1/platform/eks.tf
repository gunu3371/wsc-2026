data "aws_iam_policy_document" "eks_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["eks.amazonaws.com"] } } }
resource "aws_iam_role" "eks" { name = "wsc2026-eks-cluster-role"
assume_role_policy = data.aws_iam_policy_document.eks_assume.json }
resource "aws_iam_role_policy_attachment" "eks" { role = aws_iam_role.eks.name
policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy" }

data "aws_iam_policy_document" "node_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["ec2.amazonaws.com"] } } }
resource "aws_iam_role" "node" { for_each = toset(["addon", "workload"])
name = "wsc2026-${each.key}-node-role"
assume_role_policy = data.aws_iam_policy_document.node_assume.json }
locals { node_policies = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy", "AmazonSSMManagedInstanceCore"]) }
resource "aws_iam_role_policy_attachment" "node" { for_each = { for p in setproduct(toset(["addon", "workload"]), local.node_policies) : "${p[0]}-${p[1]}" => p }
role = aws_iam_role.node[each.value[0]].name
policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value[1]}" }

resource "aws_security_group" "eks" { name = "wsc2026-eks-cluster-sg"
vpc_id = aws_vpc.main.id
egress { from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"] }
tags = { Name = "wsc2026-eks-cluster-sg" } }
resource "aws_security_group_rule" "eks_self" { type = "ingress"
from_port = 0
to_port = 0
protocol = "-1"
self = true
security_group_id = aws_security_group.eks.id }

resource "aws_eks_cluster" "main" {
  name = "wsc2026-eks-cluster"
version = "1.35"
role_arn = aws_iam_role.eks.arn
enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  vpc_config { subnet_ids = values(aws_subnet.private)[*].id
endpoint_private_access = true
endpoint_public_access = false
security_group_ids = [aws_security_group.eks.id] }
  encryption_config { provider { key_arn = aws_kms_key.main["eks"].arn }
resources = ["secrets"] }
  depends_on = [aws_iam_role_policy_attachment.eks]
}

resource "aws_eks_addon" "pod_identity" { cluster_name = aws_eks_cluster.main.name
addon_name = "eks-pod-identity-agent" }
resource "aws_eks_node_group" "main" {
  for_each = { addon = { name = "wsc2026-addon-nodegroup", label = "addon" }, workload = { name = "wsc2026-workload-ng", label = "application" } }
  cluster_name = aws_eks_cluster.main.name
node_group_name = each.value.name
node_role_arn = aws_iam_role.node[each.key].arn
subnet_ids = values(aws_subnet.private)[*].id
instance_types = ["t3.medium"]
ami_type = "AL2023_x86_64_STANDARD"
  labels = { "wsc2026/node" = each.value.label }
  scaling_config { desired_size = 2
min_size = 1
max_size = 3 }
  update_config { max_unavailable = 1 }
  tags = { Name = "wsc2026-${each.key == "addon" ? "addon" : "workload"}-node" }
  depends_on = [aws_iam_role_policy_attachment.node]
}
