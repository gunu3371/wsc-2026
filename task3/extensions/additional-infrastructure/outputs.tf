output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.workload : name => repository.repository_url }
}

output "node_group_names" {
  value = { for name, node_group in aws_eks_node_group.workload : name => node_group.node_group_name }
}
