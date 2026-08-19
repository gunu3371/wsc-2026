variable "config" {
  description = "3과제 monitoring 입력과 foundation 출력입니다."
  type = object({
    common = object({
      aws_region   = optional(string, "ap-northeast-2")
      candidate_id = optional(string, "00000")
      project_name = optional(string, "apdev-task3")
    })
    modules = object({
      extensions = object({
        monitoring = object({})
      })
    })
    outputs = object({
      foundation = object({
        cluster_name   = string
        node_role_name = string
      })
    })
  })
  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
}
