locals {
  input = merge(var.config.common, var.config.modules.extensions.image_build, var.config.outputs.foundation, {
    tags = merge(var.config.common.tags, var.config.modules.extensions.image_build.tags)
  })
}
