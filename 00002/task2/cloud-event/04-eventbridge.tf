locals {
  rules = {
    "wsc2026-ec2-stop-rule" = {
      fn = "wsc2026-ec2-stop-remediation", pattern = {
        source = ["aws.ec2"], detail-type = ["EC2 Instance State-change Notification"], detail = {
          state = ["stopped"], instance-id = [aws_instance.event.id]
        }
      }
    },
    "wsc2026-ec2-terminate-rule" = {
      fn = "wsc2026-ec2-terminate-alert", pattern = {
        source = ["aws.ec2"], detail-type = ["EC2 Instance State-change Notification"], detail = {
          state = ["terminated"], instance-id = [aws_instance.event.id]
        }
      }
    },
    "wsc2026-sg-change-rule" = {
      fn = "wsc2026-sg-remediation", pattern = {
        source = ["aws.ec2"], detail-type = ["AWS API Call via CloudTrail"], detail = {
          eventSource = ["ec2.amazonaws.com"], eventName = ["AuthorizeSecurityGroupIngress"], requestParameters = {
            groupId = [aws_security_group.event.id]
          }
        }
      }
    },
    "wsc2026-role-change-rule" = {
      fn = "wsc2026-role-remediation", pattern = {
        source = ["aws.ec2"], detail-type = ["AWS API Call via CloudTrail"], detail = {
          eventSource = ["ec2.amazonaws.com"], eventName = ["AssociateIamInstanceProfile", "ReplaceIamInstanceProfileAssociation"]
        }
      }
    },
    "wsc2026-ec2-type-change-rule" = {
      fn = "wsc2026-ec2-type-remediation", pattern = {
        source = ["aws.ec2"], detail-type = ["AWS API Call via CloudTrail"], detail = {
          eventSource = ["ec2.amazonaws.com"], eventName = ["ModifyInstanceAttribute"]
        }
      }
    },
    "wsc2026-tag-compliance-rule" = {
      fn = "wsc2026-tag-alert", pattern = {
        source = ["aws.config"], detail-type = ["Config Rules Compliance Change"], detail = {
          newEvaluationResult = {
            complianceType = ["NON_COMPLIANT"]
          }
        }
      }
    }
  }
}
resource "aws_cloudwatch_event_rule" "this" {
  for_each      = local.rules
  name          = each.key
  event_pattern = jsonencode(each.value.pattern)
}
resource "aws_cloudwatch_event_target" "this" {
  for_each = local.rules
  rule     = aws_cloudwatch_event_rule.this[each.key].name
  arn      = aws_lambda_function.fn[each.value.fn].arn
  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }
}
resource "aws_lambda_permission" "event" {
  for_each      = local.rules
  statement_id  = "Allow-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn[each.value.fn].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[each.key].arn
}

