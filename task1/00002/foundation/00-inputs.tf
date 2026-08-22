locals {
  cleanup_mode = coalesce(
    var.config.modules.foundation.cleanup_mode,
    !var.config.modules.foundation.dynamodb_deletion_protection_enabled
  )
  input = merge(var.config.common, var.config.modules.foundation, {
    cleanup_mode                         = local.cleanup_mode
    dynamodb_deletion_protection_enabled = !local.cleanup_mode
  })
}
