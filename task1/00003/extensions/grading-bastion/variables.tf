variable "config" {
  description = "00003 과제 grading-bastion 설정과 platform 출력입니다."
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
        grading_bastion = object({})
      })
    })
    outputs = object({
      platform = object({
        vpc_id             = string
        private_subnet_ids = list(string)
        cluster_name       = string
      })
    })
  })
}
