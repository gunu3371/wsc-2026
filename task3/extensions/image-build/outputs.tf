output "project_name" { value = aws_codebuild_project.application.name }
output "source_bucket_name" { value = aws_s3_bucket.source.id }
output "binary_object_keys" { value = local.input.binary_object_keys }
output "build_targets" { value = local.build_targets }
output "start_build_command" {
  value = "aws codebuild start-build --region ${local.input.aws_region} --project-name ${aws_codebuild_project.application.name}"
}
