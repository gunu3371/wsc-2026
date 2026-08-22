variable "config" {
  description = "00003 과제의 공통 설정과 platform 출력입니다."
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
      addons = object({})
    })
    outputs = object({
      platform = object({
        cluster_name      = string
        book_table_name   = string
        book_pod_role_arn = string
        vpc_id            = string
      })
      image_build = object({
        image_uri = string
      })
    })
  })
}
