variable "config" {
  description = "00007 과제 addons 설정과 foundation/cluster 출력입니다."
  type = object({
    common = object({
      task_id      = string
      candidate_id = string
      region       = optional(string, "ap-northeast-2")
      aws_profile  = optional(string)
      tags         = optional(map(string), {})
    })
    modules = object({
      addons = object({})
    })
    outputs = object({
      foundation = object({
        vpc_id                = string
        public_subnet_ids     = list(string)
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
      image_build = object({
        image_uri = string
      })
    })
  })
}
