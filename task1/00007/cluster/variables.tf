variable "config" {
  description = "00007 과제 cluster 설정과 foundation 출력입니다."
  type = object({
    common = object({
      task_id      = string
      candidate_id = string
      region       = optional(string, "ap-northeast-2")
      aws_profile  = optional(string)
      tags         = optional(map(string), {})
    })
    modules = object({
      cluster = object({
        kubernetes_version         = optional(string, "1.35")
        eks_endpoint_public_access = optional(bool, false)
        eks_public_access_cidrs    = optional(list(string), [])
      })
    })
    outputs = object({
      foundation = object({
        private_subnet_ids = list(string)
        platform_kms_arn   = string
      })
    })
  })

  validation {
    condition     = !var.config.modules.cluster.eks_endpoint_public_access || length(var.config.modules.cluster.eks_public_access_cidrs) > 0
    error_message = "EKS public endpoint를 열 때는 허용 CIDR을 하나 이상 지정해야 합니다."
  }
}
