data "aws_iam_policy_document" "grafana_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${local.input.namespace}:${local.input.grafana_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana_cloudwatch" {
  name               = "wsc2026-grafana-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
  tags = {
    Project   = "wsc2026"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name = "wsc2026-grafana-cloudwatch-read"
  role = aws_iam_role.grafana_cloudwatch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ec2:DescribeRegions",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}
