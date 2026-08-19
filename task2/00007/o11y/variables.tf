variable "config" {
  description = "00007 과제 관측성 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      o11y = object({
        log_generator_image = string
        kubernetes_version  = optional(string, "1.35")
      })
    })
    outputs = object({})
  })
}
