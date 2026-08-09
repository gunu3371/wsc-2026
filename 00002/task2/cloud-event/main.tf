data "aws_caller_identity" "current" {}
resource "random_id" "suffix" { byte_length=4 }
resource "aws_vpc" "this" { cidr_block="10.30.0.0/16"
 enable_dns_support=true
 enable_dns_hostnames=true
 tags={Name="event-vpc"} }
resource "aws_internet_gateway" "this" { vpc_id=aws_vpc.this.id }
resource "aws_subnet" "public" { count=2
 vpc_id=aws_vpc.this.id
 cidr_block="10.30.${count.index+1}.0/24"
 availability_zone=var.availability_zones[count.index]
 map_public_ip_on_launch=true
 tags={Name="wsc2026-event-public-${count.index+1}"} }
resource "aws_route_table" "public" { vpc_id=aws_vpc.this.id
 route {cidr_block="0.0.0.0/0"
gateway_id=aws_internet_gateway.this.id} }
resource "aws_route_table_association" "public" { count=2
 subnet_id=aws_subnet.public[count.index].id
 route_table_id=aws_route_table.public.id }
resource "aws_security_group" "event" { name="wsc2026-event-sg"
 description="No public SSH ingress"
 vpc_id=aws_vpc.this.id
 egress {from_port=0
to_port=0
protocol="-1"
cidr_blocks=["0.0.0.0/0"]}
 tags={Name="wsc2026-event-sg"} }
resource "aws_iam_role" "ec2" { name="wsc2026-event-ec2-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="ec2.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy_attachment" "ssm" { role=aws_iam_role.ec2.name
 policy_arn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_iam_instance_profile" "ec2" { name="wsc2026-event-ec2-role"
 role=aws_iam_role.ec2.name }
data "aws_ssm_parameter" "ami" { name="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
resource "aws_instance" "event" { ami=data.aws_ssm_parameter.ami.value
 instance_type="t3.micro"
 subnet_id=aws_subnet.public[0].id
 vpc_security_group_ids=[aws_security_group.event.id]
 iam_instance_profile=aws_iam_instance_profile.ec2.name
 tags={Name="wsc2026-event-ec2"} }
resource "aws_sns_topic" "alert" { name="wsc2026-event-alert" }

resource "aws_s3_bucket" "audit" { bucket="wsc2026-event-audit-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
 force_destroy=true }
resource "aws_s3_bucket_public_access_block" "audit" { bucket=aws_s3_bucket.audit.id
 block_public_acls=true
ignore_public_acls=true
block_public_policy=true
restrict_public_buckets=true }
data "aws_iam_policy_document" "audit" {
  statement { actions=["s3:GetBucketAcl"]
 resources=[aws_s3_bucket.audit.arn]
 principals {type="Service"
identifiers=["cloudtrail.amazonaws.com"]} }
  statement { actions=["s3:PutObject"]
 resources=["${aws_s3_bucket.audit.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
 principals {type="Service"
identifiers=["cloudtrail.amazonaws.com"]}
 condition {test="StringEquals"
variable="s3:x-amz-acl"
values=["bucket-owner-full-control"]} }
  statement { actions=["s3:PutObject"]
 resources=["${aws_s3_bucket.audit.arn}/config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
 principals {type="Service"
identifiers=["config.amazonaws.com"]}
 condition {test="StringEquals"
variable="s3:x-amz-acl"
values=["bucket-owner-full-control"]} }
}
resource "aws_s3_bucket_policy" "audit" { bucket=aws_s3_bucket.audit.id
 policy=data.aws_iam_policy_document.audit.json }
resource "aws_cloudtrail" "event" { name="wsc2026-event-trail"
 s3_bucket_name=aws_s3_bucket.audit.id
 include_global_service_events=true
 is_multi_region_trail=false
 enable_logging=true
 event_selector {read_write_type="All"
include_management_events=true}
 depends_on=[aws_s3_bucket_policy.audit] }

data "archive_file" "remediation" { type="zip"
 source_file="${path.module}/lambda/index.py"
 output_path="${path.module}/remediation.zip" }
resource "aws_iam_role" "lambda" { name="wsc2026-event-lambda-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy" "lambda" { role=aws_iam_role.lambda.id
 policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["ec2:StartInstances","ec2:StopInstances","ec2:ModifyInstanceAttribute","ec2:RevokeSecurityGroupIngress","ec2:Describe*","ec2:ReplaceIamInstanceProfileAssociation"],Resource="*"},{Effect="Allow",Action=["iam:PassRole"],Resource=aws_iam_role.ec2.arn},{Effect="Allow",Action="sns:Publish",Resource=aws_sns_topic.alert.arn},{Effect="Allow",Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],Resource="*"}]}) }
locals {
  functions={
    "wsc2026-ec2-stop-remediation"="stop_handler",
    "wsc2026-ec2-terminate-alert"="terminate_handler",
    "wsc2026-sg-remediation"="sg_handler",
    "wsc2026-tag-alert"="tag_handler",
    "wsc2026-role-remediation"="role_handler",
    "wsc2026-ec2-type-remediation"="type_handler"
  }
}
resource "aws_lambda_function" "fn" { for_each=local.functions
 function_name=each.key
 role=aws_iam_role.lambda.arn
 runtime="python3.12"
 handler="index.${each.value}"
 filename=data.archive_file.remediation.output_path
 source_code_hash=data.archive_file.remediation.output_base64sha256
 timeout=60
 environment {variables={SNS_TOPIC_ARN=aws_sns_topic.alert.arn,INSTANCE_ID=aws_instance.event.id,SECURITY_GROUP_ID=aws_security_group.event.id,ROLE_NAME=aws_iam_instance_profile.ec2.name,INSTANCE_TYPE="t3.micro"}} }

locals { rules={
  "wsc2026-ec2-stop-rule"={fn="wsc2026-ec2-stop-remediation",pattern={source=["aws.ec2"],detail-type=["EC2 Instance State-change Notification"],detail={state=["stopped"],instance-id=[aws_instance.event.id]}}},
  "wsc2026-ec2-terminate-rule"={fn="wsc2026-ec2-terminate-alert",pattern={source=["aws.ec2"],detail-type=["EC2 Instance State-change Notification"],detail={state=["terminated"],instance-id=[aws_instance.event.id]}}},
  "wsc2026-sg-change-rule"={fn="wsc2026-sg-remediation",pattern={source=["aws.ec2"],detail-type=["AWS API Call via CloudTrail"],detail={eventSource=["ec2.amazonaws.com"],eventName=["AuthorizeSecurityGroupIngress"],requestParameters={groupId=[aws_security_group.event.id]}}}},
  "wsc2026-role-change-rule"={fn="wsc2026-role-remediation",pattern={source=["aws.ec2"],detail-type=["AWS API Call via CloudTrail"],detail={eventSource=["ec2.amazonaws.com"],eventName=["AssociateIamInstanceProfile","ReplaceIamInstanceProfileAssociation"]}}},
  "wsc2026-ec2-type-change-rule"={fn="wsc2026-ec2-type-remediation",pattern={source=["aws.ec2"],detail-type=["AWS API Call via CloudTrail"],detail={eventSource=["ec2.amazonaws.com"],eventName=["ModifyInstanceAttribute"]}}},
  "wsc2026-tag-compliance-rule"={fn="wsc2026-tag-alert",pattern={source=["aws.config"],detail-type=["Config Rules Compliance Change"],detail={newEvaluationResult={complianceType=["NON_COMPLIANT"]}}}}
} }
resource "aws_cloudwatch_event_rule" "this" { for_each=local.rules
 name=each.key
 event_pattern=jsonencode(each.value.pattern) }
resource "aws_cloudwatch_event_target" "this" { for_each=local.rules
 rule=aws_cloudwatch_event_rule.this[each.key].name
 arn=aws_lambda_function.fn[each.value.fn].arn
 retry_policy {maximum_event_age_in_seconds=3600
maximum_retry_attempts=2} }
resource "aws_lambda_permission" "event" { for_each=local.rules
 statement_id="Allow-${each.key}"
 action="lambda:InvokeFunction"
 function_name=aws_lambda_function.fn[each.value.fn].function_name
 principal="events.amazonaws.com"
 source_arn=aws_cloudwatch_event_rule.this[each.key].arn }

resource "aws_iam_role" "config" { name="wsc2026-config-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="config.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy_attachment" "config" { role=aws_iam_role.config.name
 policy_arn="arn:aws:iam::aws:policy/service-role/AWS_ConfigRole" }
resource "aws_iam_role_policy" "config_bucket" { role=aws_iam_role.config.id
 policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["s3:GetBucketAcl","s3:ListBucket"],Resource=aws_s3_bucket.audit.arn},{Effect="Allow",Action="s3:PutObject",Resource="${aws_s3_bucket.audit.arn}/config/*"}]}) }
resource "aws_config_configuration_recorder" "this" { name="wsc2026-config-recorder"
 role_arn=aws_iam_role.config.arn
 recording_group {all_supported=true
include_global_resource_types=true} }
resource "aws_config_delivery_channel" "this" { name="wsc2026-config-delivery"
 s3_bucket_name=aws_s3_bucket.audit.id
 s3_key_prefix="config"
 depends_on=[aws_s3_bucket_policy.audit] }
resource "aws_config_configuration_recorder_status" "this" { name=aws_config_configuration_recorder.this.name
 is_enabled=true
 depends_on=[aws_config_delivery_channel.this] }
resource "aws_config_config_rule" "ssh" { name="wsc2026-sg-ssh-rule"
 source {owner="AWS"
source_identifier="INCOMING_SSH_DISABLED"}
 depends_on=[aws_config_configuration_recorder.this] }
resource "aws_config_config_rule" "tags" { name="wsc2026-required-tags-rule"
 input_parameters=jsonencode({tag1Key="Name"})
 source {owner="AWS"
source_identifier="REQUIRED_TAGS"}
 depends_on=[aws_config_configuration_recorder.this] }

