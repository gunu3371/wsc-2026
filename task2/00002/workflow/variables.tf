variable "config" {
  description = "00002 과제 workflow 입력입니다."
  type = object({
    common = object({
      task_id     = string
      aws_profile = optional(string)
      tags        = optional(map(string), { Project = "wsc2026", ManagedBy = "Terraform" })
    })
    modules = object({
      workflow = object({
        lambda_runtime = optional(string, "python3.12")
      })
    })
    outputs = object({})
  })
}
