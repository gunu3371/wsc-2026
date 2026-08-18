variable "cluster_name" {
  type        = string
  description = "infra root module에서 생성한 EKS 클러스터 이름"
}

variable "keda_role_arn" {
  type        = string
  description = "infra root module에서 생성한 KEDA Pod IAM role ARN"
}

variable "karpenter_role_arn" {
  type        = string
  description = "infra root module에서 생성한 Karpenter Pod IAM role ARN"
}

variable "keda_chart_version" {
  type    = string
  default = "2.17.2"
}

variable "karpenter_chart_version" {
  type    = string
  default = "1.6.3"
}
