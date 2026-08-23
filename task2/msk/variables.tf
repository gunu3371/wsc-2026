variable "config" {
  description = "00002 과제 MSK 입력입니다."
  type = object({
    common = object({
      task_id     = string
      aws_profile = optional(string)
      tags        = optional(map(string), { Project = "wsc2026", ManagedBy = "Terraform" })
    })
    modules = object({
      msk = object({
        producer_binary_path = string
        availability_zones   = optional(list(string), ["ap-northeast-1a", "ap-northeast-1d"])
        lambda_runtime       = optional(string, "python3.14")
      })
    })
    outputs = object({})
  })
}
