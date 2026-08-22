variable "config" {
  description = "00007 과제의 공통 설정입니다."
  type = object({
    common = object({
      task_id      = string
      candidate_id = string
      region       = optional(string, "ap-northeast-2")
      aws_profile  = optional(string)
      tags         = optional(map(string), {})
    })
    modules = object({
      foundation = object({
        cleanup_mode = optional(bool, false)
      })
    })
    outputs = object({})
  })

  validation {
    condition     = can(regex("^[0-9]+$", var.config.common.candidate_id))
    error_message = "candidate_id에는 선수등번호 숫자만 입력해야 합니다."
  }
}
