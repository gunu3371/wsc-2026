variable "aws_profile" {
  type    = string
  default = null
}
variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-1a", "eu-west-1b"]
}
variable "tags" {
  type = map(string)
  default = {
    Project = "wsc2026", ManagedBy = "Terraform"
  }
}

