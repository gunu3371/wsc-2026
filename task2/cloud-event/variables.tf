variable "config" {
  description = "00002 과제 cloud-event 입력입니다."
  type = object({
    common = object({
      task_id     = string
      aws_profile = optional(string)
      tags        = optional(map(string), { Project = "wsc2026", ManagedBy = "Terraform" })
    })
    modules = object({
      cloud_event = object({
        availability_zones = optional(list(string), ["eu-west-1a", "eu-west-1b"])
      })
    })
    outputs = object({})
  })
}
