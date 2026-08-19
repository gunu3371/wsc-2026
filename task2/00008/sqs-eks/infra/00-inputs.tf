locals {
  input = merge(var.config.common, var.config.modules.sqs_eks.infra)
}
