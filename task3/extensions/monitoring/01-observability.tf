data "aws_eks_node_group" "core" {
  cluster_name    = local.input.cluster_name
  node_group_name = local.input.core_node_group_name
}

data "aws_eks_node_group" "stress" {
  cluster_name    = local.input.cluster_name
  node_group_name = local.input.stress_node_group_name
}

data "aws_eks_node_group" "additional" {
  for_each = local.input.additional_node_group_names

  cluster_name    = local.input.cluster_name
  node_group_name = each.value
}

locals {
  core_asg_name   = data.aws_eks_node_group.core.resources[0].autoscaling_groups[0].name
  stress_asg_name = data.aws_eks_node_group.stress.resources[0].autoscaling_groups[0].name
  additional_asg_names = {
    for name, node_group in data.aws_eks_node_group.additional :
    name => node_group.resources[0].autoscaling_groups[0].name
  }
  node_cpu_metrics = concat(
    [
      ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", local.core_asg_name, { label = "core" }],
      [".", ".", ".", local.stress_asg_name, { label = "stress" }],
    ],
    [
      for name in sort(keys(local.additional_asg_names)) :
      [".", ".", ".", local.additional_asg_names[name], { label = name }]
    ],
  )
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${local.input.cluster_name}/application"
  retention_in_days = local.input.log_retention_days
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${local.input.project_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "fluent_bit" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.application.arn}:*"]
  }
}

resource "aws_iam_role_policy" "fluent_bit" {
  name   = "application-log-delivery"
  role   = aws_iam_role.fluent_bit.id
  policy = data.aws_iam_policy_document.fluent_bit.json
}

resource "kubernetes_service_account_v1" "fluent_bit" {
  metadata {
    name      = "aws-for-fluent-bit"
    namespace = "kube-system"
  }
}

resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = local.input.cluster_name
  namespace       = kubernetes_service_account_v1.fluent_bit.metadata[0].namespace
  service_account = kubernetes_service_account_v1.fluent_bit.metadata[0].name
  role_arn        = aws_iam_role.fluent_bit.arn

  depends_on = [aws_iam_role_policy.fluent_bit]
}

resource "helm_release" "fluent_bit" {
  name       = "aws-for-fluent-bit"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = local.input.fluent_bit_chart_version

  wait    = true
  timeout = 600

  values = [yamlencode({
    image = {
      repository = "public.ecr.aws/aws-observability/aws-for-fluent-bit"
      tag        = "3.2.1"
      pullPolicy = "IfNotPresent"
    }
    serviceAccount = {
      create = false
      name   = kubernetes_service_account_v1.fluent_bit.metadata[0].name
    }
    input = {
      enabled         = true
      path            = "/var/log/containers/*.log"
      db              = "/var/log/flb_kube.db"
      memBufLimit     = "5MB"
      multilineParser = "docker, cri"
      refreshInterval = 10
      skipLongLines   = "On"
      tag             = "kube.*"
    }
    filter = {
      enabled           = true
      match             = "kube.*"
      kubeURL           = "https://kubernetes.default.svc.cluster.local:443"
      mergeLog          = "On"
      mergeLogKey       = "data"
      keepLog           = "On"
      k8sLoggingParser  = "On"
      k8sLoggingExclude = "On"
      bufferSize        = "32k"
    }
    additionalFilters = <<-FILTER
      [FILTER]
          Name   grep
          Match  kube.*
          Regex  $kubernetes['namespace_name'] ^apdev$
    FILTER
    cloudWatch        = { enabled = false }
    cloudWatchLogs = {
      enabled           = true
      match             = "kube.*"
      region            = local.input.aws_region
      logGroupName      = aws_cloudwatch_log_group.application.name
      logStreamTemplate = "$kubernetes['pod_name'].$kubernetes['container_name']"
      autoCreateGroup   = false
      autoRetryRequests = true
    }
    resources = {
      requests = { cpu = "20m", memory = "50Mi" }
      limits   = { cpu = "100m", memory = "128Mi" }
    }
    tolerations = [{
      key      = "dedicated"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
  })]

  depends_on = [
    aws_eks_pod_identity_association.fluent_bit,
    aws_cloudwatch_log_group.application,
  ]
}

resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${local.input.project_name}-application-errors"
  pattern        = "?ERROR ?Exception ?panic"
  log_group_name = aws_cloudwatch_log_group.application.name

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "Task3/${local.input.project_name}"
    value     = "1"
  }
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

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.input.project_name}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title = "ALB target latency (p95 / p99)", region = local.input.aws_region, view = "timeSeries", period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.input.alb_arn_suffix, { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }],
          ]
          yAxis = { left = { min = 0, label = "Seconds" } }
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title = "ALB status codes", region = local.input.aws_region, view = "timeSeries", period = 60, stat = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", local.input.alb_arn_suffix, { label = "Target 2xx" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { label = "Target 4xx" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { label = "Target 5xx" }],
            [".", "HTTPCode_ELB_4XX_Count", ".", ".", { label = "ALB 4xx" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { label = "ALB 5xx" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title = "Target group p95 / p99", region = local.input.aws_region, view = "timeSeries", period = 60
          metrics = [
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer,TargetGroup} MetricName=\"TargetResponseTime\" LoadBalancer=\"${local.input.alb_arn_suffix}\"', 'p95', 60)", id = "tg_p95", label = "TG p95" }],
            [{ expression = "SEARCH('{AWS/ApplicationELB,LoadBalancer,TargetGroup} MetricName=\"TargetResponseTime\" LoadBalancer=\"${local.input.alb_arn_suffix}\"', 'p99', 60)", id = "tg_p99", label = "TG p99" }],
          ]
          yAxis = { left = { min = 0, label = "Seconds" } }
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title   = "Node group CPU", region = local.input.aws_region, view = "timeSeries", period = 60, stat = "Average"
          metrics = local.node_cpu_metrics
          yAxis   = { left = { min = 0, max = 100, label = "Percent" } }
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title = "RDS health", region = local.input.aws_region, view = "timeSeries", period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "apdev-rds-instance", { stat = "Average", label = "CPU %" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Average", label = "Connections", yAxis = "right" }],
            [".", "ReadLatency", ".", ".", { stat = "Average", label = "Read latency", yAxis = "right" }],
            [".", "WriteLatency", ".", ".", { stat = "Average", label = "Write latency", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title = "CloudFront requests and errors", region = "us-east-1", view = "timeSeries", period = 60
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", local.input.cloudfront_distribution_id, "Region", "Global", { stat = "Sum", label = "Requests" }],
            [".", "4xxErrorRate", ".", ".", ".", ".", { stat = "Average", label = "4xx %", yAxis = "right" }],
            [".", "5xxErrorRate", ".", ".", ".", ".", { stat = "Average", label = "5xx %", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 18, width = 12, height = 6
        properties = {
          title = "CloudFront WAF requests", region = "us-east-1", view = "timeSeries", period = 60, stat = "Sum"
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", local.input.waf_web_acl_name, "Rule", "ALL", "Region", "CloudFront", { label = "Allowed" }],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", ".", { label = "Blocked" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 18, width = 12, height = 6
        properties = {
          title   = "Application errors", region = local.input.aws_region, view = "timeSeries", period = 60, stat = "Sum"
          metrics = [["Task3/${local.input.project_name}", "ApplicationErrors"]]
        }
      },
      {
        type = "log", x = 0, y = 24, width = 24, height = 6
        properties = {
          title  = "Recent application errors"
          region = local.input.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.application.name}' | fields @timestamp, kubernetes.pod_name, kubernetes.container_name, log | filter log like /ERROR|Exception|panic/ | sort @timestamp desc | limit 50"
        }
      },
    ]
  })
}
