variable "config" {
  description = "00008 과제 SQS/EKS controller 입력과 infra 출력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      sqs_eks = object({
        addons = object({
          controllers = object({
            keda_chart_version      = optional(string, "2.17.2")
            karpenter_chart_version = optional(string, "1.6.3")
          })
        })
      })
    })
    outputs = object({
      sqs_eks_infra = object({
        cluster_name       = string
        keda_role_arn      = string
        karpenter_role_arn = string
      })
    })
  })
}
