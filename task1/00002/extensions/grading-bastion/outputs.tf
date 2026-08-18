output "instance_id" {
  description = "SSM으로만 사용하는 일회성 이미지 푸시 베스천 ID"
  value       = aws_instance.bastion.id
}

output "ecr_repository_url" {
  value = data.aws_ecr_repository.book.repository_url
}

output "build_bucket" {
  value = data.aws_s3_bucket.build_artifacts.id
}
