variable "config" {
  description = "00008 과제 cloud-event 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      cloud_event = object({
        force_destroy = optional(bool, false)
        cleanup_mode  = optional(bool, false)
      })
    })
    outputs = object({})
  })
}
