variable "config" {
  description = "00008 과제 DocumentDB 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      documentdb = object({
        client_allowed_cidrs = optional(list(string), ["0.0.0.0/0"])
        skip_final_snapshot  = optional(bool, false)
        cleanup_mode         = optional(bool, false)
      })
    })
    outputs = object({})
  })
}
