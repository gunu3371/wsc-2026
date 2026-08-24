locals {
  input = merge(
    var.config.common,
    var.config.modules.extensions.image_build,
    { additional_workloads = var.config.modules.extensions.additional_workloads },
    var.config.outputs.foundation,
    { additional_ecr_repository_urls = var.config.outputs.additional_infrastructure.ecr_repository_urls },
  )
}
