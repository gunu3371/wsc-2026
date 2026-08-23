output "alb_url" {
  value = "http://${aws_lb.this.dns_name}"
}
output "stream_arn" {
  value = aws_kinesis_stream.orders.arn
}
output "flink_application_arn" {
  value = "arn:aws:kinesisanalytics:ap-northeast-2:${data.aws_caller_identity.current.account_id}:application/${awscc_kinesisanalyticsv2_application.flink.application_name}"
}
