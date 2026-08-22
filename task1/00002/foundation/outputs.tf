output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.web.domain_name}"
}
output "alb_url" {
  value = "http://${aws_lb.book.dns_name}"
}
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}
output "ecr_repository_url" {
  value = aws_ecr_repository.book.repository_url
}
output "cluster_endpoint" {
  value     = aws_eks_cluster.main.endpoint
  sensitive = true
}
output "cluster_ca" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}
output "dynamodb_table_name" {
  value = aws_dynamodb_table.book.name
}

output "s3_bucket_name" {
  description = "선수 등번호가 포함된 정적 웹 자산 S3 버킷 이름"
  value       = aws_s3_bucket.web.bucket
}

output "cloudshell_vpc_id" {
  description = "CloudShell VPC environment에서 선택할 VPC ID"
  value       = aws_vpc.main.id
}

output "cloudshell_subnet_id" {
  description = "CloudShell VPC environment에서 선택할 private subnet-d ID"
  value       = aws_subnet.private[1].id
}

output "cloudshell_security_group_id" {
  description = "CloudShell VPC environment에서 선택할 전용 security group ID"
  value       = aws_security_group.cloudshell.id
}
