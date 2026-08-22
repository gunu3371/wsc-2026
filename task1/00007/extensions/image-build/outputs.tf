output "project_name" {
  value = aws_codebuild_project.image_build.name
}

output "repository_url" {
  value = data.aws_ecr_repository.book.repository_url
}

output "image_tag" {
  value = "v1.0.0"
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.image_build.name
}
