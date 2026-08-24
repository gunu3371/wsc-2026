resource "aws_eks_cluster" "main" {
  name     = local.input.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = local.input.kubernetes_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "core" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.input.project_name}-workers"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = local.input.node_groups.core.instance_types
  capacity_type   = local.input.node_groups.core.capacity_type
  disk_size       = local.input.node_groups.core.disk_size

  scaling_config {
    desired_size = local.input.node_groups.core.desired_size
    min_size     = local.input.node_groups.core.min_size
    max_size     = local.input.node_groups.core.max_size
  }

  labels = { workload = "core" }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_iam_role_policy_attachment.eks_node_cni,
  ]
}

moved {
  from = aws_eks_node_group.main
  to   = aws_eks_node_group.core
}

resource "aws_eks_node_group" "stress" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.input.project_name}-stress"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = local.input.node_groups.stress.instance_types
  capacity_type   = local.input.node_groups.stress.capacity_type
  disk_size       = local.input.node_groups.stress.disk_size

  scaling_config {
    desired_size = local.input.node_groups.stress.desired_size
    min_size     = local.input.node_groups.stress.min_size
    max_size     = local.input.node_groups.stress.max_size
  }

  labels = { workload = "stress" }

  taint {
    key    = "dedicated"
    value  = "stress"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_iam_role_policy_attachment.eks_node_cni,
  ]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.core, aws_eks_node_group.stress]
}

resource "aws_eks_access_entry" "additional_admin" {
  for_each = local.input.additional_cluster_admin_principal_arns

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "additional_admin" {
  for_each = local.input.additional_cluster_admin_principal_arns

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.additional_admin]
}
