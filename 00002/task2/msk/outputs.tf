output "msk_cluster_arn" { value=aws_msk_cluster.this.arn }
output "bootstrap_brokers_sasl_iam" { value=aws_msk_cluster.this.bootstrap_brokers_sasl_iam
sensitive=true }
output "producer_instance_id" { value=aws_instance.producer.id }
output "dynamodb_table" { value=aws_dynamodb_table.data.name }
output "alert_bucket" { value=aws_s3_bucket.alert.id }

