locals {
  input = merge(var.config.common, var.config.modules.delivery, var.config.outputs.platform, var.config.outputs.addons)

  lambda_origin = trimsuffix(trimprefix(local.input.lambda_function_url, "https://"), "/")
}
