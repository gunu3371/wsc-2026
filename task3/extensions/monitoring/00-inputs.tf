locals {
  input = merge(
    var.config.common,
    var.config.modules.extensions.monitoring,
    var.config.outputs.foundation,
    { additional_node_group_names = var.config.outputs.additional_infrastructure.node_group_names },
    var.config.outputs.application,
  )
}
