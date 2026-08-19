variable "config" {
  description = "00007 과제 NoSQL 입력입니다."
  type = object({
    common  = object({ task_id = string })
    modules = object({ nosql = object({}) })
    outputs = object({})
  })
}
