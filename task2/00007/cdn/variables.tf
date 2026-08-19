variable "config" {
  description = "00007 과제 CDN 입력입니다."
  type = object({
    common  = object({ task_id = string })
    modules = object({ cdn = object({}) })
    outputs = object({})
  })
}
