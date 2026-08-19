variable "config" {
  description = "00003 과제의 공통 설정과 platform 출력입니다."
  type = object({
    common = object({
      task_id     = string
      region      = optional(string, "ap-northeast-2")
      aws_profile = optional(string)
      tags        = optional(map(string), {})
    })
    modules = object({
      addons = object({})
    })
    outputs = object({
      platform = object({
        cluster_name    = string
        book_table_name = string
        image_uri       = string
        vpc_id          = string
      })
    })
  })
}
