output "cluster_name" {
  value = aws_eks_cluster.main.name
}
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}
output "cluster_ca" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}
output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}
output "vpc_id" {
  value = aws_vpc.main.id
}
output "book_table_name" {
  value = aws_dynamodb_table.book.name
}
output "book_table_arn" {
  value = aws_dynamodb_table.book.arn
}
output "book_pod_role_arn" {
  value = aws_iam_role.book_pod.arn
}
output "ecr_repository_url" {
  value = aws_ecr_repository.book.repository_url
}
output "static_bucket_name" {
  value = aws_s3_bucket.static.id
}
output "static_bucket_regional_domain_name" {
  value = aws_s3_bucket.static.bucket_regional_domain_name
}
output "bucket_kms_arn" {
  value = aws_kms_key.main["bucket"].arn
}
output "lambda_function_url" {
  value = aws_lambda_function_url.book_get.function_url
}
