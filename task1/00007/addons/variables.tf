variable "config" {
  description = "00007 과제 addons 설정과 foundation/cluster 출력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      addons = object({
        app_image           = string
        audit_principal_arn = string
      })
    })
    outputs = object({
      foundation = object({
        vpc_id                = string
        private_subnet_ids    = list(string)
        table_arn             = string
        app_kms_arn           = string
        platform_kms_arn      = string
        platform_use1_kms_arn = string
        bucket_name           = string
      })
      cluster = object({
        cluster_name              = string
        cluster_endpoint          = string
        cluster_ca                = string
        cluster_security_group_id = string
      })
    })
  })
}
