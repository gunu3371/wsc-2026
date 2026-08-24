resource "aws_ecr_repository" "workload" {
  for_each = local.input.additional_workloads

  name                 = "${local.input.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
