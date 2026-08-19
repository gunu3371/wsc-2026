locals {
  input = merge(var.config.common, var.config.modules.extensions.observability_fix, var.config.outputs.platform)
}
