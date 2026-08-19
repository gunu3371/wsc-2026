locals {
  input = merge(var.config.common, var.config.modules.sqs_eks.addons.controllers, var.config.outputs.sqs_eks_infra)
}
