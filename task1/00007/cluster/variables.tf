variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Foundation root module에서 생성한 private subnet ID 목록"
}

variable "platform_kms_arn" {
  type        = string
  description = "Foundation root module에서 생성한 EKS secrets 암호화 KMS key ARN"
}
