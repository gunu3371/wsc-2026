variable "config" {
  description = "3과제 공통 설정과 foundation 입력입니다."
  type = object({
    common = object({
      aws_region   = optional(string, "ap-northeast-2")
      candidate_id = optional(string, "00000")
      project_name = optional(string, "apdev-task3")
    })
    modules = object({
      foundation = object({
        vpc_cidr                                = optional(string, "10.30.0.0/16")
        cluster_name                            = optional(string, "apdev-eks-cluster")
        kubernetes_version                      = optional(string)
        additional_cluster_admin_principal_arns = optional(set(string), [])
        db_username                             = optional(string, "appuser")
      })
    })
    outputs = object({})
  })
  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
}
