variable "config" {
  description = "3과제 CodeBuild image-build extension 입력과 foundation 출력입니다."
  type = object({
    common = object({
      aws_region   = optional(string, "ap-northeast-2")
      candidate_id = optional(string, "00000")
      project_name = optional(string, "apdev-task3")
    })
    modules = object({
      extensions = object({
        image_build = object({
          build_image  = optional(string, "aws/codebuild/amazonlinux-x86_64-standard:6.0")
          compute_type = optional(string, "BUILD_GENERAL1_SMALL")
          image_tag    = optional(string, "latest")
          binary_object_keys = optional(object({
            user    = optional(string, "binaries/user")
            product = optional(string, "binaries/product")
            stress  = optional(string, "binaries/stress")
          }), {})
          log_retention_days = optional(number, 1)
        })
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
        ecr_repository_urls = map(string)
      })
      additional_infrastructure = object({
        ecr_repository_urls = map(string)
        node_group_names    = map(string)
      })
    })
  })

  validation {
    condition     = var.config.common.aws_region == "ap-northeast-2"
    error_message = "3과제 리전은 ap-northeast-2여야 합니다."
  }
  validation {
    condition = alltrue([
      for name, workload in var.config.modules.extensions.additional_workloads :
      contains(keys(var.config.outputs.additional_infrastructure.ecr_repository_urls), name) &&
      length(trimspace(workload.binary_object_key)) > 0 && !startswith(workload.binary_object_key, "/") &&
      can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", workload.image_tag))
    ])
    error_message = "추가 build target마다 ECR output, 상대 binary object key와 유효한 image tag가 필요합니다."
  }
  validation {
    condition = length(distinct(concat(
      values(var.config.modules.extensions.image_build.binary_object_keys),
      [for workload in values(var.config.modules.extensions.additional_workloads) : workload.binary_object_key],
    ))) == 3 + length(var.config.modules.extensions.additional_workloads)
    error_message = "기본 및 추가 workload의 binary object key는 서로 중복될 수 없습니다."
  }
  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.config.modules.extensions.image_build.image_tag))
    error_message = "CodeBuild image_tag는 유효한 Docker tag 형식이어야 합니다."
  }
  validation {
    condition = (
      alltrue([
        for key in values(var.config.modules.extensions.image_build.binary_object_keys) :
        length(trimspace(key)) > 0 && !startswith(key, "/")
      ]) &&
      length(distinct(values(var.config.modules.extensions.image_build.binary_object_keys))) == 3
    )
    error_message = "binary_object_keys는 서로 다르고 비어 있지 않은 상대 S3 object key여야 합니다."
  }
  validation {
    condition = alltrue([
      for name in ["user", "product", "stress"] :
      contains(keys(var.config.outputs.foundation.ecr_repository_urls), name)
    ])
    error_message = "foundation ecr_repository_urls에는 user, product, stress가 모두 있어야 합니다."
  }
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.config.modules.extensions.image_build.log_retention_days)
    error_message = "CodeBuild 로그 보존 기간은 1, 3, 5, 7, 14, 30일 중 하나여야 합니다."
  }
}
