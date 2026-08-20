locals {
  input = merge(var.config.common, var.config.modules.extensions.image_build, {
    tags = merge(var.config.common.tags, var.config.modules.extensions.image_build.tags)
  })
}
