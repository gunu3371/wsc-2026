locals {
  input = merge(var.config.common, var.config.modules.addons, var.config.outputs.platform, var.config.outputs.image_build, {
    table_name = var.config.outputs.platform.book_table_name
  })
}
