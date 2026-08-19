variable "config" {
  description = "00002 과제 analytics 입력입니다."
  type = object({
    common = object({
      task_id     = string
      aws_profile = optional(string)
      tags        = optional(map(string), { Project = "wsc2026", ManagedBy = "Terraform" })
    })
    modules = object({
      analytics = object({
        availability_zones = optional(list(string), ["ap-northeast-2a", "ap-northeast-2b"])
        allowed_cidr       = optional(string, "0.0.0.0/0")
      })
    })
    outputs = object({})
  })
}
