variable "config" {
  description = "00002 과제의 공통 설정, application 입력과 foundation 출력입니다."
  type = object({
    common = object({
      task_id     = string
      aws_profile = optional(string)
      tags        = optional(map(string), {})
    })
    modules = object({
      application = object({
        book_image_uri         = string
        grafana_admin_password = optional(string, "$korea26!!")
      })
    })
    outputs = object({
      foundation = object({
        eks_cluster_name    = string
        cluster_endpoint    = string
        cluster_ca          = string
        dynamodb_table_name = string
      })
    })
  })
}
