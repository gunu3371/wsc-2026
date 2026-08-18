variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "cluster_name" {
  type    = string
  default = "wsc2026-eks-cluster"
}

variable "namespace" {
  type    = string
  default = "observability"
}

variable "grafana_service_account" {
  type    = string
  default = "wsc2026-prometheus-grafana"
}

variable "grafana_deployment" {
  type    = string
  default = "wsc2026-prometheus-grafana"
}
