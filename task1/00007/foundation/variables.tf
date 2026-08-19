variable "config" {
  description = "00007 과제의 공통 설정입니다."
  type = object({
    common  = object({ task_id = string })
    modules = object({ foundation = object({}) })
    outputs = object({})
  })
}
