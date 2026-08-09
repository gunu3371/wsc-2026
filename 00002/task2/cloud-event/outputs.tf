output "instance_id" { value=aws_instance.event.id }
output "security_group_id" { value=aws_security_group.event.id }
output "sns_topic_arn" { value=aws_sns_topic.alert.arn }
output "cloudtrail_arn" { value=aws_cloudtrail.event.arn }
