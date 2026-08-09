variable "aws_profile" { type=string
 default=null }
variable "candidate_id" { type=string }
variable "producer_binary_path" { type=string }
variable "availability_zones" { type=list(string)
 default=["ap-northeast-1a","ap-northeast-1d"] }
variable "lambda_runtime" { type=string
 default="python3.14" }
variable "tags" { type=map(string)
 default={Project="wsc2026",ManagedBy="Terraform"} }

