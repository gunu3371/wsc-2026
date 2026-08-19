variable "config" {
  description = "00008 과제 SQS/EKS infra 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      sqs_eks = object({
        infra = object({
          kubernetes_version          = optional(string, "1.35")
          cluster_public_access_cidrs = optional(list(string), ["0.0.0.0/0"])
          cleanup_mode                = optional(bool, false)
        })
      })
    })
    outputs = object({})
  })
}
