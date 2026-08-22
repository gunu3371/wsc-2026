variable "config" {
  description = "00003 과제의 공식 book 이미지 CodeBuild 설정입니다."
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
      extensions = object({
        image_build = object({
          build_timeout_minutes = optional(number, 10)
          tags                  = optional(map(string), { Purpose = "one-time-ecr-image-build" })
        })
      })
    })
    outputs = object({
      platform = object({
        static_bucket_name = string
        bucket_kms_arn     = string
        ecr_repository_url = string
      })
    })
  })

  validation {
    condition     = var.config.modules.extensions.image_build.build_timeout_minutes >= 5 && var.config.modules.extensions.image_build.build_timeout_minutes <= 60
    error_message = "image-build의 build_timeout_minutes는 5~60분이어야 합니다."
  }
}
