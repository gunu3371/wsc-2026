variable "config" {
  description = "00008 과제 SQS/EKS workload 입력과 infra 출력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      sqs_eks = object({
        addons = object({
          workloads = object({
            worker_image = optional(string)
          })
        })
      })
    })
    outputs = object({
      sqs_eks_infra = object({
        cluster_name          = string
        worker_role_arn       = string
        worker_repository_url = string
        queue_url             = string
        node_role_name        = string
      })
    })
  })
}
