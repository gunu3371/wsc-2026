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

variable "database_secret_arn" {
  description = "foundation output database_secret_arn"
  type        = string
}

variable "image_bucket_name" {
  description = "foundation output image_bucket_name"
  type        = string
}

variable "product_pod_role_arn" {
  description = "foundation output product_pod_role_arn"
  type        = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "replicas" {
  description = "Initial replica count per application."
  type        = number
  default     = 2
  validation {
    condition     = var.replicas >= 2
    error_message = "At least two replicas are required for availability."
  }
}
