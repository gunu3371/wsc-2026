locals {
  input = merge(var.config.common, var.config.modules.cluster, var.config.outputs.foundation)
}
