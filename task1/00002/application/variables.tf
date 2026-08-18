variable "aws_profile" {
  type    = string
  default = null
}
variable "task_id" {
  type = string
}
variable "eks_cluster_name" {
  type        = string
  description = "Foundation root module에서 생성한 EKS 클러스터 이름"
}
variable "cluster_endpoint" {
  type        = string
  description = "Foundation root module에서 생성한 EKS API endpoint"
}
variable "cluster_ca" {
  type        = string
  sensitive   = true
  description = "Foundation root module에서 생성한 EKS CA 데이터(base64)"
}
variable "dynamodb_table_name" {
  type        = string
  description = "Foundation root module에서 생성한 DynamoDB 테이블 이름"
}
variable "book_image_uri" {
  type = string
}
variable "grafana_admin_password" {
  type      = string
  default   = "$korea26!!"
  sensitive = true
}
