locals {
  input = merge(var.config.common, var.config.modules.extensions.grading_bastion, {
    tags = merge(var.config.common.tags, var.config.modules.extensions.grading_bastion.tags)
  })
}
