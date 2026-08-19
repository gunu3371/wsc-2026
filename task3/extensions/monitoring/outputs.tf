output "dashboard_name" { value = aws_cloudwatch_dashboard.main.dashboard_name }
output "application_log_group" { value = "/aws/containerinsights/${local.input.cluster_name}/application" }
