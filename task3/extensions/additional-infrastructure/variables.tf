variable "config" {
  description = "3과제 추가 workload 전용 ECR과 EKS node group 입력입니다."
  type = object({
    common = object({
      aws_region   = optional(string, "ap-northeast-2")
      candidate_id = optional(string, "00000")
      project_name = optional(string, "apdev-task3")
    })
    modules = object({
      extensions = object({
        additional_workloads = optional(map(object({
          binary_object_key = string
          image_tag         = optional(string, "latest")
          route_path        = string
          container_port    = optional(number, 8080)
          healthcheck_path  = optional(string, "/healthcheck")
          replicas          = optional(number, 2)
          min_replicas      = optional(number, 2)
          max_replicas      = optional(number, 3)
          hpa_cpu_percent   = optional(number, 70)
          use_database      = optional(bool, false)
          environment       = optional(map(string), {})
          node_group = optional(object({
            instance_types = optional(list(string), ["t3.medium"])
            capacity_type  = optional(string, "ON_DEMAND")
            disk_size      = optional(number, 30)
            desired_size   = optional(number, 1)
            min_size       = optional(number, 1)
            max_size       = optional(number, 1)
          }), {})
          resources = optional(object({
            requests = optional(object({
              cpu    = optional(string, "100m")
              memory = optional(string, "128Mi")
            }), {})
            limits = optional(object({
              cpu    = optional(string, "750m")
              memory = optional(string, "512Mi")
            }), {})
          }), {})
        })), {})
      })
    })
    outputs = object({
      foundation = object({
        cluster_name       = string
        private_subnet_ids = list(string)
        node_role_arn      = string
      })
    })
  })

  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
  validation {
    condition = (
      length(var.config.modules.extensions.additional_workloads) <= 50 &&
      alltrue([
        for name in keys(var.config.modules.extensions.additional_workloads) :
        length(name) <= 30 && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name)) &&
        !contains(["application", "application-fallback", "database", "product", "stress", "user"], name) &&
        length("${var.config.common.project_name}-${name}") <= 63
      ])
    )
    error_message = "additional_workloads key는 소문자·숫자·하이픈 형식의 30자 이하 이름이어야 하며 최대 50개까지 지정할 수 있습니다."
  }
  validation {
    condition = alltrue([
      for workload in values(var.config.modules.extensions.additional_workloads) :
      startswith(workload.route_path, "/") && workload.route_path != "/" &&
      startswith(workload.healthcheck_path, "/") &&
      !anytrue([
        for reserved in ["/v1/user", "/v1/product", "/v1/stress", "/healthcheck", "/images"] :
        startswith(workload.route_path, reserved)
      ])
    ])
    error_message = "추가 route_path와 healthcheck_path는 /로 시작해야 하며 기존 API·이미지 경로와 겹칠 수 없습니다."
  }
  validation {
    condition = (
      length(distinct([for workload in values(var.config.modules.extensions.additional_workloads) : workload.route_path])) == length(var.config.modules.extensions.additional_workloads) &&
      length(distinct([for workload in values(var.config.modules.extensions.additional_workloads) : workload.binary_object_key])) == length(var.config.modules.extensions.additional_workloads) &&
      alltrue(flatten([
        for name, workload in var.config.modules.extensions.additional_workloads : [
          for other_name, other in var.config.modules.extensions.additional_workloads :
          name == other_name || !startswith(workload.route_path, "${other.route_path}/")
        ]
      ]))
    )
    error_message = "추가 workload의 route_path와 binary_object_key는 중복될 수 없고 route prefix끼리 겹칠 수 없습니다."
  }
  validation {
    condition = alltrue([
      for workload in values(var.config.modules.extensions.additional_workloads) :
      length(trimspace(workload.binary_object_key)) > 0 && !startswith(workload.binary_object_key, "/") &&
      can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", workload.image_tag)) &&
      workload.container_port >= 1 && workload.container_port <= 65535 && workload.container_port % 1 == 0 &&
      workload.min_replicas >= 1 && workload.min_replicas <= workload.replicas && workload.replicas <= workload.max_replicas &&
      workload.hpa_cpu_percent >= 1 && workload.hpa_cpu_percent <= 100
    ])
    error_message = "추가 workload의 binary key, image tag, port, replica 또는 HPA 설정이 유효하지 않습니다."
  }
  validation {
    condition = alltrue(flatten([
      for workload in values(var.config.modules.extensions.additional_workloads) : [
        length(workload.node_group.instance_types) > 0,
        alltrue([for instance_type in workload.node_group.instance_types : instance_type == "t3.medium"]),
        contains(["ON_DEMAND", "SPOT"], workload.node_group.capacity_type),
        workload.node_group.disk_size >= 20,
        workload.node_group.min_size >= 1,
        workload.node_group.min_size <= workload.node_group.desired_size,
        workload.node_group.desired_size <= workload.node_group.max_size,
      ]
    ]))
    error_message = "추가 node group은 t3.medium을 사용하고 min <= desired <= max 및 20GiB 이상 디스크 조건을 만족해야 합니다."
  }
  validation {
    condition = alltrue(flatten([
      for workload in values(var.config.modules.extensions.additional_workloads) : [
        for name in keys(workload.environment) :
        can(regex("^[A-Za-z_][A-Za-z0-9_]*$", name)) &&
        !(workload.use_database && contains(["MYSQL_USER", "MYSQL_PASSWORD", "MYSQL_HOST", "MYSQL_PORT", "MYSQL_DBNAME"], name))
      ]
    ]))
    error_message = "환경변수 이름이 잘못됐거나 use_database가 관리하는 MYSQL_* 이름과 충돌합니다."
  }
}
