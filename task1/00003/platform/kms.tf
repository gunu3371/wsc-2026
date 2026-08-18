data "aws_iam_policy_document" "kms" {

  statement {

    sid       = "KeyAdministrators"
    actions   = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }

  }
  statement {
    sid       = "TerraformCallerUse"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }
  statement {

    sid       = "ServiceUse"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["dynamodb.amazonaws.com", "ecr.amazonaws.com", "eks.amazonaws.com", "s3.amazonaws.com", "lambda.amazonaws.com", "logs.${var.region}.amazonaws.com"]
    }

  }
  statement {

    sid       = "ServiceGrants"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["dynamodb.amazonaws.com", "ecr.amazonaws.com", "eks.amazonaws.com", "s3.amazonaws.com", "lambda.amazonaws.com", "logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

  }

}

data "aws_iam_policy_document" "kms_bucket" {
  source_policy_documents = [data.aws_iam_policy_document.kms.json]
  statement {
    sid       = "CloudFrontStaticObjectDecrypt"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:s3:::wsc2026-static-${local.suffix}-${lower(var.candidate_id)}-bucket",
        "arn:${data.aws_partition.current.partition}:s3:::wsc2026-static-${local.suffix}-${lower(var.candidate_id)}-bucket/*"
      ]
    }
  }
}

data "aws_iam_policy_document" "kms_db" {
  source_policy_documents = [data.aws_iam_policy_document.kms.json]
  statement {
    sid       = "BookFunctionDynamoDBDecrypt"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.book_function.arn, "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/wsc2026-book-pod-role"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "main" {
  for_each                = local.kms_aliases
  description             = "wsc2026 ${each.key} CMK"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = each.key == "bucket" ? data.aws_iam_policy_document.kms_bucket.json : each.key == "db" ? data.aws_iam_policy_document.kms_db.json : data.aws_iam_policy_document.kms.json
}
resource "aws_kms_alias" "main" {
  for_each      = local.kms_aliases
  name          = "alias/wsc2026-${each.key}-kms"
  target_key_id = aws_kms_key.main[each.key].key_id
}
