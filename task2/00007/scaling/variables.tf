variable "config" {
  description = "00007 과제 scaling 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      scaling = object({
        order_processor_image = string
        kubernetes_version    = optional(string, "1.35")
      })
    })
    outputs = object({})
  })
}
