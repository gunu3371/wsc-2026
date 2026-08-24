locals {
  input = merge(
    var.config.common,
    { additional_workloads = var.config.modules.extensions.additional_workloads },
    var.config.outputs.foundation,
    var.config.outputs.additional_infrastructure,
  )
}
