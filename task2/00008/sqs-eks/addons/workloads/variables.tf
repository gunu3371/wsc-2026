variable "worker_image" {
  type    = string
  default = null
}

variable "cluster_name" {
  type        = string
  description = "infra root module에서 생성한 EKS 클러스터 이름"
}

variable "worker_role_arn" {
  type        = string
  description = "infra root module에서 생성한 worker Pod IAM role ARN"
}

variable "worker_repository_url" {
  type        = string
  description = "infra root module에서 생성한 worker ECR repository URL"
}

variable "queue_url" {
  type        = string
  description = "infra root module에서 생성한 SQS queue URL"
}

variable "node_role_name" {
  type        = string
  description = "infra root module에서 생성한 Karpenter node IAM role 이름"
}
