variable "aws_region" {
  description = "AWS region. The task requires ap-northeast-2."
  type        = string
  default     = "ap-northeast-2"

  validation {
    condition     = var.aws_region == "ap-northeast-2"
    error_message = "Task 3 resources must be deployed in ap-northeast-2."
  }
}

variable "candidate_id" {
  description = "Candidate number used only for tags and globally unique names."
  type        = string
  default     = "00000"
}

variable "project_name" {
  description = "Prefix for resources without a fixed name in the task."
  type        = string
  default     = "apdev-task3"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.30.0.0/16"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "apdev-eks-cluster"
}

variable "kubernetes_version" {
  description = "Optional EKS Kubernetes version. Null uses the current EKS default."
  type        = string
  default     = null
}

variable "additional_cluster_admin_principal_arns" {
  description = "IAM role/user ARNs that need EKS administrator access, for example the CloudShell role."
  type        = set(string)
  default     = []
}

variable "db_username" {
  description = "Application database administrator username."
  type        = string
  default     = "appuser"
}
