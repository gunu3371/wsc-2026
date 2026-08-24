resource "aws_eks_node_group" "workload" {
  for_each = local.input.additional_workloads

  cluster_name    = local.input.cluster_name
  node_group_name = "${local.input.project_name}-${each.key}"
  node_role_arn   = local.input.node_role_arn
  subnet_ids      = local.input.private_subnet_ids
  instance_types  = each.value.node_group.instance_types
  capacity_type   = each.value.node_group.capacity_type
  disk_size       = each.value.node_group.disk_size

  scaling_config {
    desired_size = each.value.node_group.desired_size
    min_size     = each.value.node_group.min_size
    max_size     = each.value.node_group.max_size
  }

  labels = { workload = each.key }

  taint {
    key    = "dedicated"
    value  = each.key
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1
  }
}
