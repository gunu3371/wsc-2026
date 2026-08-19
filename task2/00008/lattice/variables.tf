variable "config" {
  description = "00008 과제 VPC Lattice 입력입니다."
  type = object({
    common = object({ task_id = string })
    modules = object({
      lattice = object({
        client_allowed_cidrs = optional(list(string), ["0.0.0.0/0"])
      })
    })
    outputs = object({})
  })
}
