variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
  validation {
    condition     = var.aws_region == "ap-northeast-2"
    error_message = "Task 3 resources must be deployed in ap-northeast-2."
  }
}

variable "candidate_id" {
  type    = string
  default = "00000"
}

variable "project_name" {
  type    = string
  default = "apdev-task3"
}

variable "cluster_name" {
  type    = string
  default = "apdev-eks-cluster"
}

variable "node_role_name" {
  description = "foundation output node_role_name"
  type        = string
}
