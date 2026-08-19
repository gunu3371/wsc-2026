data "aws_partition" "current" {}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = local.input.node_role_name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = local.input.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_iam_role_policy_attachment.cloudwatch_agent]
}

resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${local.input.project_name}-application-errors"
  pattern        = "?ERROR ?Exception ?panic"
  log_group_name = "/aws/containerinsights/${local.input.cluster_name}/application"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "Task3/${local.input.project_name}"
    value     = "1"
  }

  depends_on = [aws_eks_addon.cloudwatch_observability]
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${local.input.project_name}-application-errors"
  alarm_description   = "Application ERROR/Exception/panic log events detected"
  namespace           = "Task3/${local.input.project_name}"
  metric_name         = "ApplicationErrors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "failed_nodes" {
  alarm_name          = "${local.input.project_name}-failed-nodes"
  alarm_description   = "EKS Container Insights reports failed nodes"
  namespace           = "ContainerInsights"
  metric_name         = "cluster_failed_node_count"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = local.input.cluster_name
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.input.project_name}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS node CPU and memory"
          region = local.input.aws_region
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", local.input.cluster_name],
            [".", "node_memory_utilization", ".", "."]
          ]
          period = 60
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Application errors"
          region  = local.input.aws_region
          metrics = [["Task3/${local.input.project_name}", "ApplicationErrors"]]
          period  = 60
          stat    = "Sum"
          view    = "timeSeries"
        }
      }
    ]
  })
}
