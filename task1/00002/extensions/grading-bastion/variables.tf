variable "config" {
  description = "00002 과제의 공통 설정과 grading-bastion 입력입니다."
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
        grading_bastion = object({
          instance_type = optional(string, "t3.micro")
          tags = optional(map(string), {
            Purpose = "one-time-ecr-push"
          })
        })
      })
    })
    outputs = object({
      foundation = object({
        s3_bucket_name = string
      })
    })
  })
}
