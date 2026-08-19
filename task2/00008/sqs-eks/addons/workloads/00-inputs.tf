locals {
  input = merge(var.config.common, var.config.modules.sqs_eks.addons.workloads, var.config.outputs.sqs_eks_infra)
}
