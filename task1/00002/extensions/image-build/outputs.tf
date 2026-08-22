output "project_name" {
  value = aws_codebuild_project.image_build.name
}

output "image_uri" {
  value = "${data.aws_ecr_repository.book.repository_url}:stable"
}

output "repository_name" {
  value = data.aws_ecr_repository.book.name
}
