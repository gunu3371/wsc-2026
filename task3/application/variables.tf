variable "config" {
  description = "3과제 application 입력과 foundation 출력입니다."
  type = object({
    common = object({
      aws_region   = optional(string, "ap-northeast-2")
      candidate_id = optional(string, "00000")
      project_name = optional(string, "apdev-task3")
    })
    modules = object({
      application = object({
        image_tag = optional(string, "latest")
        replicas  = optional(number, 2)
      })
    })
    outputs = object({
      foundation = object({
        cluster_name         = string
        database_secret_arn  = string
        image_bucket_name    = string
        product_pod_role_arn = string
      })
    })
  })
  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
  validation {
    condition     = var.config.modules.application.replicas >= 2
    error_message = "application replicas는 2 이상이어야 합니다."
  }
}
