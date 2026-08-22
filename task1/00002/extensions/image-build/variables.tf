variable "config" {
  description = "00002 과제의 공통 설정과 image-build extension 입력입니다."
  type = object({
    common = object({
      task_id      = string
      candidate_id = string
      region       = optional(string, "ap-northeast-2")
      aws_profile  = optional(string)
      tags         = optional(map(string), {})
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
      foundation = object({
        s3_bucket_name = string
      })
    })
  })

  validation {
    condition     = var.config.modules.extensions.image_build.build_timeout_minutes >= 5 && var.config.modules.extensions.image_build.build_timeout_minutes <= 60
    error_message = "image-build의 build_timeout_minutes는 5~60분이어야 합니다."
  }
}
