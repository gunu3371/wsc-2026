variable "config" {
  description = "00002 과제의 공통 설정, application 입력과 foundation 출력입니다."
  type = object({
    common = object({
      task_id      = string
      candidate_id = string
      aws_profile  = optional(string)
      tags         = optional(map(string), {})
    })
    modules = object({
      application = object({
        grafana_admin_password = optional(string, "$korea26!!")
      })
    })
    outputs = object({
      foundation = object({
        eks_cluster_name    = string
        cluster_endpoint    = string
        cluster_ca          = string
        dynamodb_table_name = string
      })
    })
  })


  validation {
    condition     = length(trimspace(var.config.common.candidate_id)) > 0 && var.config.common.candidate_id != "replace-with-candidate-number"
    error_message = "common.candidate_id에는 대회 당일 부여받은 실제 선수 비번호를 입력해야 합니다."
  }
}
