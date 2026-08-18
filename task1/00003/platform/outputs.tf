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
output "image_uri" {
  value = var.image_uri
}
output "static_bucket_name" {
  value = aws_s3_bucket.static.id
}
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.main.domain_name
}
