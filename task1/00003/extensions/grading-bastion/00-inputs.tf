locals {
  input = merge(var.config.common, var.config.modules.extensions.grading_bastion, var.config.outputs.platform, {
    subnet_id = var.config.outputs.platform.private_subnet_ids[0]
  })
}
