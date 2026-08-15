variable "aws_profile" {
  type    = string
  default = null
}
variable "candidate_id" {
  type = string
}
variable "availability_zones" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2b"]
}
variable "allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
variable "tags" {
  type = map(string)
  default = {
    Project = "wsc2026", ManagedBy = "Terraform"
  }
}

