output "grafana_cloudwatch_role_arn" {
  value = aws_iam_role.grafana_cloudwatch.arn
}

output "managed_dashboard_config_map" {
  value = kubernetes_config_map_v1.dashboard.metadata[0].name
}
