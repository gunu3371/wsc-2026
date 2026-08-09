variable "aws_profile" { type=string
 default=null }
variable "candidate_id" { type=string }
variable "lambda_runtime" { type=string
 default="python3.12" }
variable "tags" { type=map(string)
 default={Project="wsc2026",ManagedBy="Terraform"} }

