locals {
  input = merge(var.config.common, var.config.modules.extensions.monitoring, var.config.outputs.foundation)
}
