locals {
  input = merge(var.config.common, var.config.modules.addons, var.config.outputs.foundation, var.config.outputs.cluster, var.config.outputs.image_build)
}
