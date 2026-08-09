output "alb_url" { value="http://${aws_lb.this.dns_name}" }
output "stream_arn" { value=aws_kinesis_stream.orders.arn }
output "flink_application_arn" { value=aws_kinesisanalyticsv2_application.flink.arn }
