variable "region" {
  type    = string
  default = "ap-northeast-2"
}
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "cluster_name" {
  type    = string
  default = "wsc2026-eks-cluster"
}
