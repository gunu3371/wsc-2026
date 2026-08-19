variable "config" {
  description = "00003 과제 observability-fix 설정과 platform 출력입니다."
  type = object({
    common = object({
      task_id     = string
      region      = optional(string, "ap-northeast-2")
      aws_profile = optional(string)
      tags        = optional(map(string), {})
    })
    modules = object({
      extensions = object({
        observability_fix = object({
          namespace               = optional(string, "observability")
          grafana_service_account = optional(string, "wsc2026-prometheus-grafana")
          grafana_deployment      = optional(string, "wsc2026-prometheus-grafana")
        })
      })
    })
    outputs = object({
      platform = object({
        cluster_name = string
      })
    })
  })
}
