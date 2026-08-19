variable "config" {
  description = "00007 과제 cluster 설정과 foundation 출력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      cluster = object({
        kubernetes_version = optional(string, "1.35")
      })
    })
    outputs = object({
      foundation = object({
        private_subnet_ids = list(string)
        platform_kms_arn   = string
      })
    })
  })
}
