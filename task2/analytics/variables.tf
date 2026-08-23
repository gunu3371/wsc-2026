variable "config" {
  description = "00002 과제 Analytics 입력입니다."
  type = object({
    common = object({
      task_id          = string
      candidate_number = string
      aws_profile      = optional(string)
      tags             = optional(map(string), { Project = "wsc2026", ManagedBy = "Terraform" })
    })
    modules = object({
      analytics = object({
        availability_zones        = optional(list(string), ["ap-northeast-2a", "ap-northeast-2b"])
        alb_ingress_cidrs         = optional(list(string), ["0.0.0.0/0"])
        flink_runtime_environment = optional(string, "ZEPPELIN-FLINK-3_0")
      })
    })
    outputs = object({})
  })
}
