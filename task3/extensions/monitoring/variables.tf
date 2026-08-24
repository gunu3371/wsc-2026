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
        monitoring = object({
          fluent_bit_chart_version = optional(string, "0.2.0")
          log_retention_days       = optional(number, 1)
        })
      })
    })
    outputs = object({
      foundation = object({
        cluster_name           = string
        core_node_group_name   = string
        stress_node_group_name = string
      })
      additional_infrastructure = object({
        ecr_repository_urls = map(string)
        node_group_names    = map(string)
      })
      application = object({
        alb_arn_suffix             = string
        cloudfront_distribution_id = string
        waf_web_acl_name           = string
      })
    })
  })
  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.config.modules.extensions.monitoring.log_retention_days)
    error_message = "CloudWatch Logs 보존 기간은 1, 3, 5, 7, 14, 30일 중 하나여야 합니다."
  }
}
