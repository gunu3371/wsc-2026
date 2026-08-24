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
        image_tag                       = optional(string, "latest")
        replicas                        = optional(number, 2)
        aws_load_balancer_chart_version = optional(string, "1.14.0")
        blocked_user_agents             = optional(set(string), [])
        blocked_user_agent_action       = optional(string, "BLOCK")
      })
    })
    outputs = object({
      foundation = object({
        cluster_name         = string
        vpc_id               = string
        public_subnet_ids    = list(string)
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
  validation {
    condition = (
      length(var.config.modules.application.blocked_user_agents) <= 50 &&
      alltrue([for user_agent in var.config.modules.application.blocked_user_agents : length(trimspace(user_agent)) > 0]) &&
      length(distinct([for user_agent in var.config.modules.application.blocked_user_agents : lower(trimspace(user_agent))])) == length(var.config.modules.application.blocked_user_agents)
    )
    error_message = "blocked_user_agents는 빈 문자열과 대소문자만 다른 중복 없이 최대 50개까지 지정할 수 있습니다."
  }
  validation {
    condition     = contains(["BLOCK", "COUNT"], upper(var.config.modules.application.blocked_user_agent_action))
    error_message = "blocked_user_agent_action은 BLOCK 또는 COUNT여야 합니다."
  }
}
