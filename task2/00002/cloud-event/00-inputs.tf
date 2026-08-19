locals {
  input = merge(var.config.common, var.config.modules.cloud_event)
}
