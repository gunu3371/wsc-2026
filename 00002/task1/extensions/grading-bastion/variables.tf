variable "candidate_id" {
  type = string
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "wskorea26-concert"
    ManagedBy = "Terraform"
    Purpose   = "one-time-ecr-push"
  }
}
