variable "config" {
  description = "00002 과제의 공통 설정과 foundation 입력입니다."
  type = object({
    common = object({
      task_id      = string
      candidate_id = string
      aws_profile  = optional(string)
      tags         = optional(map(string), {})
    })
    modules = object({
      foundation = object({
        availability_zones                      = optional(list(string), ["ap-northeast-2c", "ap-northeast-2d"])
        cluster_version                         = optional(string, "1.35")
        lambda_runtime                          = optional(string, "python3.14")
        dynamodb_deletion_protection_enabled    = optional(bool, true)
        additional_cluster_admin_principal_arns = optional(set(string), [])
      })
    })
    outputs = object({})
  })
  validation {
    condition     = length(var.config.modules.foundation.availability_zones) == 2
    error_message = "foundation에는 정확히 두 개의 가용 영역이 필요합니다."
  }

  validation {
    condition     = length(trimspace(var.config.common.candidate_id)) > 0 && var.config.common.candidate_id != "replace-with-candidate-number"
    error_message = "common.candidate_id에는 대회 당일 부여받은 실제 선수 비번호를 입력해야 합니다."
  }

  validation {
    condition = alltrue([
      for principal_arn in var.config.modules.foundation.additional_cluster_admin_principal_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/.+$", principal_arn))
    ])
    error_message = "추가 EKS 관리자는 root 또는 STS 세션 ARN이 아닌 영구 IAM user/role ARN이어야 합니다."
  }
}
