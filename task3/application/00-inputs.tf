locals {
  input = merge(var.config.common, var.config.modules.application, var.config.outputs.foundation)
}
