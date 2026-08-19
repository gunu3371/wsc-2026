variable "config" {
  description = "00008 과제 SQS/EKS grading-bastion 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      sqs_eks = object({
        extensions = object({
          grading_bastion = object({})
        })
      })
    })
    outputs = object({
      sqs_eks_infra = object({
        cluster_name = string
      })
    })
  })
}
