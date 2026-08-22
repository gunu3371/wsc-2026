variable "config" {
  description = "00003 과제의 공통 설정과 platform 입력입니다."
  type = object({
    common = object({
      task_id           = string
      candidate_id      = string
      candidate_letters = string
      region            = optional(string, "ap-northeast-2")
      aws_profile       = optional(string)
      tags              = optional(map(string), {})
    })
    modules = object({
      platform = object({
        eks_endpoint_public_access = optional(bool, false)
        eks_public_access_cidrs    = optional(list(string), [])
        cleanup_mode               = optional(bool, false)
        static_files               = optional(map(string), {})
      })
    })
    outputs = object({})
  })
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.config.common.task_id))
    error_message = "task_id에는 영문자, 숫자와 하이픈만 사용할 수 있습니다."
  }
  validation {
    condition     = can(regex("^[0-9]+$", var.config.common.candidate_id))
    error_message = "candidate_id에는 선수 비번호 숫자만 입력해야 합니다."
  }
  validation {
    condition     = can(regex("^[a-z]{4}$", var.config.common.candidate_letters))
    error_message = "candidate_letters에는 S3 버킷 이름에 사용할 영문 소문자 네 자리를 입력해야 합니다."
  }
  validation {
    condition     = !var.config.modules.platform.eks_endpoint_public_access || length(var.config.modules.platform.eks_public_access_cidrs) > 0
    error_message = "EKS public endpoint를 열 때는 허용 CIDR을 하나 이상 지정해야 합니다."
  }
}
