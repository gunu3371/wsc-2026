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
        node_groups = optional(object({
          core = optional(object({
            instance_types = optional(list(string), ["t3.medium"])
            capacity_type  = optional(string, "ON_DEMAND")
            disk_size      = optional(number, 30)
            desired_size   = optional(number, 2)
            min_size       = optional(number, 2)
            max_size       = optional(number, 2)
          }), {})
          stress = optional(object({
            instance_types = optional(list(string), ["t3.medium"])
            capacity_type  = optional(string, "ON_DEMAND")
            disk_size      = optional(number, 30)
            desired_size   = optional(number, 1)
            min_size       = optional(number, 1)
            max_size       = optional(number, 1)
          }), {})
        }), {})
      })
    })
    outputs = object({})
  })
  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
  validation {
    condition = (
      length(var.config.modules.foundation.node_groups.core.instance_types) > 0 &&
      length(var.config.modules.foundation.node_groups.stress.instance_types) > 0 &&
      alltrue(concat(
        [for instance_type in var.config.modules.foundation.node_groups.core.instance_types : instance_type == "t3.medium"],
        [for instance_type in var.config.modules.foundation.node_groups.stress.instance_types : instance_type == "t3.medium"]
      ))
    )
    error_message = "3과제 EKS 노드 인스턴스 타입은 t3.medium만 사용할 수 있습니다."
  }
  validation {
    condition = (
      var.config.modules.foundation.node_groups.core.min_size <= var.config.modules.foundation.node_groups.core.desired_size &&
      var.config.modules.foundation.node_groups.core.desired_size <= var.config.modules.foundation.node_groups.core.max_size &&
      var.config.modules.foundation.node_groups.core.min_size >= 2 &&
      var.config.modules.foundation.node_groups.stress.min_size <= var.config.modules.foundation.node_groups.stress.desired_size &&
      var.config.modules.foundation.node_groups.stress.desired_size <= var.config.modules.foundation.node_groups.stress.max_size &&
      var.config.modules.foundation.node_groups.stress.min_size >= 1
    )
    error_message = "노드 그룹 크기는 min <= desired <= max여야 하며 core min은 2 이상, stress min은 1 이상이어야 합니다."
  }
}
