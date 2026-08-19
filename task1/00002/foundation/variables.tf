variable "config" {
  description = "00002 과제의 공통 설정과 foundation 입력입니다."
  type = object({
    common = object({
      task_id     = string
      aws_profile = optional(string)
      tags        = optional(map(string), {})
    })
    modules = object({
      foundation = object({
        availability_zones                   = optional(list(string), ["ap-northeast-2c", "ap-northeast-2d"])
        cluster_version                      = optional(string, "1.35")
        lambda_runtime                       = optional(string, "python3.14")
        dynamodb_deletion_protection_enabled = optional(bool, true)
      })
    })
    outputs = object({})
  })
  validation {
    condition     = length(var.config.modules.foundation.availability_zones) == 2
    error_message = "foundation에는 정확히 두 개의 가용 영역이 필요합니다."
  }
}
