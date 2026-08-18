variable "app_image" { type = string }
variable "audit_principal_arn" { type = string }
variable "task_id" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "table_arn" { type = string }
variable "app_kms_arn" { type = string }
variable "platform_kms_arn" { type = string }
variable "platform_use1_kms_arn" { type = string }
variable "bucket_name" { type = string }
variable "cluster_name" { type = string }
variable "cluster_endpoint" { type = string }
variable "cluster_ca" {
  type      = string
  sensitive = true
}
variable "cluster_security_group_id" { type = string }
