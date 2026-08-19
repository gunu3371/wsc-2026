variable "config" {
  description = "00003 과제 grading-bastion 설정과 platform 출력입니다."
  type = object({
    common = object({
      task_id = string
      region  = optional(string, "ap-northeast-2")
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
