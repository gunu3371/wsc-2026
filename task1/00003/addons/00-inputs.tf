locals {
  input = merge(var.config.common, var.config.modules.addons, var.config.outputs.platform, {
    table_name = var.config.outputs.platform.book_table_name
  })
}
