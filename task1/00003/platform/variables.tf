variable "config" {
  description = "00003 과제의 공통 설정과 platform 입력입니다."
  type = object({
    common = object({
      task_id     = string
      region      = optional(string, "ap-northeast-2")
      aws_profile = optional(string)
      tags        = optional(map(string), {})
    })
    modules = object({
      platform = object({
        bucket_random_suffix       = optional(string)
        image_uri                  = optional(string, "public.ecr.aws/docker/library/nginx:1.27")
        alb_domain_name            = optional(string, "example.invalid")
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
    condition     = !var.config.modules.platform.eks_endpoint_public_access || length(var.config.modules.platform.eks_public_access_cidrs) > 0
    error_message = "EKS public endpoint를 열 때는 허용 CIDR을 하나 이상 지정해야 합니다."
  }
}
