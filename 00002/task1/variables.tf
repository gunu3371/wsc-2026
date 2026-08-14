variable "candidate_id" {
  type = string
}
variable "aws_profile" {
  type    = string
  default = null
}
variable "availability_zones" {
  type    = list(string)
  default = ["ap-northeast-2c", "ap-northeast-2d"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "availability_zones must contain exactly two zones."
  }
}
variable "cluster_version" {
  type    = string
  default = "1.35"
}
variable "lambda_runtime" {
  type    = string
  default = "python3.14"
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "book_image_uri" {
  type    = string
  default = "nginx:1.27-alpine"
}
variable "grafana_admin_password" {
  type      = string
  default   = "$korea26!!"
  sensitive = true
}
