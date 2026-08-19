locals {
  input = merge(var.config.common, var.config.modules.sqs_eks.extensions.grading_bastion, var.config.outputs.sqs_eks_infra)
}
