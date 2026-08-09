locals { metric_namespace = "Skills/CloudComputing/Task1" }
resource "aws_cloudwatch_log_metric_filter" "http_4xx" {
  name           = "skills-book-4xx-filter"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "{ $.status >= 400 && $.status < 500 }"
  metric_transformation {
    name      = "skills-book-4xx-count"
    namespace = local.metric_namespace
    value     = "1"
  }
}
resource "aws_cloudwatch_log_metric_filter" "http_5xx" {
  name           = "skills-book-5xx-filter"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "{ $.status >= 500 && $.status < 600 }"
  metric_transformation {
    name      = "skills-book-5xx-count"
    namespace = local.metric_namespace
    value     = "1"
  }
}
resource "aws_cloudwatch_metric_alarm" "http_4xx" {
  alarm_name          = "skills-book-4xx-alarm"
  namespace           = local.metric_namespace
  metric_name         = "skills-book-4xx-count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}
resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "skills-book-5xx-alarm"
  namespace           = local.metric_namespace
  metric_name         = "skills-book-5xx-count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}

