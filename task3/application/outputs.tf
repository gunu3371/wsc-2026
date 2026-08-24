output "endpoint" {
  description = "Submit this scheme-and-host-only endpoint to the grading platform."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "origin_load_balancer_hostname" {
  value = data.aws_lb.application.dns_name
}

output "alb_name" { value = data.aws_lb.application.name }
output "alb_arn_suffix" { value = data.aws_lb.application.arn_suffix }
output "alb_access_log_bucket_name" { value = aws_s3_bucket.alb_logs.id }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.main.id }
output "waf_web_acl_name" { value = aws_wafv2_web_acl.main.name }
