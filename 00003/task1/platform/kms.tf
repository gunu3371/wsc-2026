data "aws_iam_policy_document" "kms" {
  statement {
    sid = "KeyAdministrators"
    actions = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"]
    resources = ["*"]
    principals { type = "AWS"
identifiers = [data.aws_caller_identity.current.arn] }
  }
  statement {
    sid = "ServiceUse"
    actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals { type = "Service"
identifiers = ["dynamodb.amazonaws.com", "ecr.amazonaws.com", "eks.amazonaws.com", "s3.amazonaws.com", "lambda.amazonaws.com", "logs.${var.region}.amazonaws.com"] }
  }
  statement {
    sid = "ServiceGrants"
    actions = ["kms:CreateGrant"]
    resources = ["*"]
    principals { type = "Service"
identifiers = ["dynamodb.amazonaws.com", "ecr.amazonaws.com", "eks.amazonaws.com", "s3.amazonaws.com", "lambda.amazonaws.com", "logs.${var.region}.amazonaws.com"] }
    condition { test = "Bool"
variable = "kms:GrantIsForAWSResource"
values = ["true"] }
  }
}

resource "aws_kms_key" "main" { for_each = local.kms_aliases
description = "wsc2026 ${each.key} CMK"
enable_key_rotation = true
deletion_window_in_days = 7
policy = data.aws_iam_policy_document.kms.json }
resource "aws_kms_alias" "main" { for_each = local.kms_aliases
name = "alias/wsc2026-${each.key}-kms"
target_key_id = aws_kms_key.main[each.key].key_id }
