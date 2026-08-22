variable "config" {
  description = "00003 과제의 CloudFront, WAF와 S3 OAC 설정입니다."
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
      delivery = object({})
    })
    outputs = object({
      platform = object({
        static_bucket_name                 = string
        static_bucket_regional_domain_name = string
        lambda_function_url                = string
      })
      addons = object({
        alb_hostname = string
      })
    })
  })
}
