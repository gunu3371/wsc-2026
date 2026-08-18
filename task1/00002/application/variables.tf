variable "aws_profile" {
  type    = string
  default = null
}
variable "candidate_id" {
  type = string
}
variable "book_image_uri" {
  type = string
}
variable "grafana_admin_password" {
  type      = string
  default   = "$korea26!!"
  sensitive = true
}
