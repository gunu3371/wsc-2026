output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }

output "cluster_name" { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}
output "node_role_name" { value = aws_iam_role.eks_node.name }
output "node_role_arn" { value = aws_iam_role.eks_node.arn }
output "core_node_group_name" { value = aws_eks_node_group.core.node_group_name }
output "stress_node_group_name" { value = aws_eks_node_group.stress.node_group_name }

output "database_secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "database_endpoint" { value = aws_db_instance.main.endpoint }

output "image_bucket_name" { value = aws_s3_bucket.images.id }
output "product_pod_role_arn" { value = aws_iam_role.product.arn }
output "ecr_repository_urls" {
  value = { for name, repository in aws_ecr_repository.application : name => repository.repository_url }
}
