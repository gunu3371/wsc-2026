output "endpoint" {
  description = "Submit this scheme-and-host-only endpoint to the grading platform."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "origin_load_balancer_hostname" {
  value = data.kubernetes_service_v1.ingress.status[0].load_balancer[0].ingress[0].hostname
}
