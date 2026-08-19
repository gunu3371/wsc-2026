locals {
  input = merge(var.config.common, var.config.modules.o11y)
}
