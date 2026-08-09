data "aws_caller_identity" "current" {}
locals { az=["a","d"]
 public=["192.168.1.0/24","192.168.2.0/24"]
 private=["192.168.101.0/24","192.168.102.0/24"]
 bucket="wsc2026-sensor-alert-bucket-${var.candidate_id}" }
resource "aws_vpc" "this" { cidr_block="192.168.0.0/16"
 enable_dns_support=true
 enable_dns_hostnames=true
 tags={Name="msk-vpc"} }
resource "aws_internet_gateway" "this" { vpc_id=aws_vpc.this.id }
resource "aws_subnet" "public" { count=2
 vpc_id=aws_vpc.this.id
 cidr_block=local.public[count.index]
 availability_zone=var.availability_zones[count.index]
 map_public_ip_on_launch=true
 tags={Name="wsc2026-msk-public-${local.az[count.index]}"} }
resource "aws_subnet" "private" { count=2
 vpc_id=aws_vpc.this.id
 cidr_block=local.private[count.index]
 availability_zone=var.availability_zones[count.index]
 tags={Name="wsc2026-msk-private-${local.az[count.index]}"} }
resource "aws_eip" "nat" { domain="vpc" }
resource "aws_nat_gateway" "this" { allocation_id=aws_eip.nat.id
 subnet_id=aws_subnet.public[0].id
 depends_on=[aws_internet_gateway.this] }
resource "aws_route_table" "public" { vpc_id=aws_vpc.this.id
 route {cidr_block="0.0.0.0/0"
gateway_id=aws_internet_gateway.this.id} }
resource "aws_route_table_association" "public" { count=2
 subnet_id=aws_subnet.public[count.index].id
route_table_id=aws_route_table.public.id }
resource "aws_route_table" "private" { vpc_id=aws_vpc.this.id
 route {cidr_block="0.0.0.0/0"
nat_gateway_id=aws_nat_gateway.this.id} }
resource "aws_route_table_association" "private" { count=2
 subnet_id=aws_subnet.private[count.index].id
route_table_id=aws_route_table.private.id }
resource "aws_security_group" "clients" { name="wsc2026-msk-client-sg"
vpc_id=aws_vpc.this.id
egress {from_port=0
to_port=0
protocol="-1"
cidr_blocks=["0.0.0.0/0"]} }
resource "aws_security_group" "msk" { name="wsc2026-msk-sg"
vpc_id=aws_vpc.this.id
ingress {from_port=9098
to_port=9098
protocol="tcp"
security_groups=[aws_security_group.clients.id]}
egress {from_port=0
to_port=0
protocol="-1"
cidr_blocks=["0.0.0.0/0"]} }

resource "aws_cloudwatch_log_group" "msk" { name="/aws/msk/wsc2026-msk-cluster"
retention_in_days=14 }
resource "aws_msk_cluster" "this" {
  cluster_name="wsc2026-msk-cluster"
 kafka_version="3.6.0"
 number_of_broker_nodes=2
  broker_node_group_info { instance_type="kafka.t3.small"
 client_subnets=aws_subnet.private[*].id
 security_groups=[aws_security_group.msk.id]
 storage_info {ebs_storage_info {volume_size=100}} }
  client_authentication { sasl {iam=true
scram=false}
 unauthenticated=false }
  encryption_info { encryption_in_transit {client_broker="TLS"
in_cluster=true} }
  logging_info { broker_logs { cloudwatch_logs {enabled=true
log_group=aws_cloudwatch_log_group.msk.name} } }
}

resource "aws_dynamodb_table" "data" { name="wsc2026-sensor-data"
billing_mode="PAY_PER_REQUEST"
hash_key="sensorId"
range_key="timestamp"
attribute {name="sensorId"
type="S"}
attribute {name="timestamp"
type="S"} }
resource "aws_s3_bucket" "alert" { bucket=local.bucket }
resource "aws_s3_bucket_public_access_block" "alert" { bucket=aws_s3_bucket.alert.id
block_public_acls=true
ignore_public_acls=true
block_public_policy=true
restrict_public_buckets=true }
resource "aws_s3_object" "producer" { bucket=aws_s3_bucket.alert.id
key="bootstrap/app"
source=var.producer_binary_path
etag=filemd5(var.producer_binary_path) }
resource "aws_sns_topic" "alert" { name="wsc2026-sensor-alert" }

resource "aws_iam_role" "producer" { name="wsc2026-sensor-producer-role"
assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="ec2.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy_attachment" "producer_ssm" { role=aws_iam_role.producer.name
policy_arn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_iam_role_policy" "producer" { role=aws_iam_role.producer.id
policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["kafka-cluster:Connect","kafka-cluster:DescribeCluster"],Resource=aws_msk_cluster.this.arn},{Effect="Allow",Action=["kafka-cluster:CreateTopic","kafka-cluster:DescribeTopic","kafka-cluster:WriteData"],Resource="arn:aws:kafka:ap-northeast-1:${data.aws_caller_identity.current.account_id}:topic/wsc2026-msk-cluster/*/*"},{Effect="Allow",Action="s3:GetObject",Resource=aws_s3_object.producer.arn}]}) }
resource "aws_iam_instance_profile" "producer" { name="wsc2026-sensor-producer-profile"
role=aws_iam_role.producer.name }
data "aws_ssm_parameter" "ami" { name="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
resource "aws_instance" "producer" { ami=data.aws_ssm_parameter.ami.value
instance_type="t3.small"
subnet_id=aws_subnet.private[0].id
vpc_security_group_ids=[aws_security_group.clients.id]
iam_instance_profile=aws_iam_instance_profile.producer.name
user_data=templatefile("${path.module}/user_data.sh.tftpl",{bucket=aws_s3_bucket.alert.id,bootstrap=aws_msk_cluster.this.bootstrap_brokers_sasl_iam,region="ap-northeast-1"})
tags={Name="wsc2026-sensor-producer"}
depends_on=[aws_s3_object.producer] }

data "archive_file" "consumer" { type="zip"
source_file="${path.module}/lambda/consumer.py"
output_path="${path.module}/consumer.zip" }
data "archive_file" "alert_consumer" { type="zip"
source_file="${path.module}/lambda/alert_consumer.py"
output_path="${path.module}/alert-consumer.zip" }
resource "aws_iam_role" "lambda" { name="wsc2026-sensor-lambda-role"
assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy" "lambda" { role=aws_iam_role.lambda.id
policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["kafka:DescribeCluster","kafka:GetBootstrapBrokers"],Resource=aws_msk_cluster.this.arn},{Effect="Allow",Action=["kafka-cluster:Connect","kafka-cluster:DescribeGroup","kafka-cluster:AlterGroup"],Resource=[aws_msk_cluster.this.arn,"arn:aws:kafka:ap-northeast-1:${data.aws_caller_identity.current.account_id}:group/wsc2026-msk-cluster/*/*"]},{Effect="Allow",Action=["kafka-cluster:DescribeTopic","kafka-cluster:ReadData"],Resource="arn:aws:kafka:ap-northeast-1:${data.aws_caller_identity.current.account_id}:topic/wsc2026-msk-cluster/*/*"},{Effect="Allow",Action=["ec2:CreateNetworkInterface","ec2:DescribeNetworkInterfaces","ec2:DescribeVpcs","ec2:DescribeSubnets","ec2:DescribeSecurityGroups","ec2:DeleteNetworkInterface"],Resource="*"},{Effect="Allow",Action="dynamodb:PutItem",Resource=aws_dynamodb_table.data.arn},{Effect="Allow",Action="s3:PutObject",Resource="${aws_s3_bucket.alert.arn}/alert/*"},{Effect="Allow",Action="sns:Publish",Resource=aws_sns_topic.alert.arn},{Effect="Allow",Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],Resource="*"}]}) }
resource "aws_lambda_function" "consumer" { function_name="wsc2026-sensor-consumer"
role=aws_iam_role.lambda.arn
runtime=var.lambda_runtime
handler="consumer.handler"
filename=data.archive_file.consumer.output_path
source_code_hash=data.archive_file.consumer.output_base64sha256
timeout=60
vpc_config {subnet_ids=aws_subnet.private[*].id
security_group_ids=[aws_security_group.clients.id]}
environment {variables={DDB_TABLE=aws_dynamodb_table.data.name,ALERT_TOPIC="wsc2026-sensor-alert",BOOTSTRAP_SERVER=aws_msk_cluster.this.bootstrap_brokers_sasl_iam,SNS_TOPIC_ARN=aws_sns_topic.alert.arn,S3_BUCKET=aws_s3_bucket.alert.id}} }
resource "aws_lambda_function" "alert" { function_name="wsc2026-sensor-alert-consumer"
role=aws_iam_role.lambda.arn
runtime=var.lambda_runtime
handler="alert_consumer.handler"
filename=data.archive_file.alert_consumer.output_path
source_code_hash=data.archive_file.alert_consumer.output_base64sha256
timeout=60
vpc_config {subnet_ids=aws_subnet.private[*].id
security_group_ids=[aws_security_group.clients.id]}
environment {variables={SNS_TOPIC_ARN=aws_sns_topic.alert.arn,S3_BUCKET=aws_s3_bucket.alert.id}} }
resource "aws_lambda_event_source_mapping" "raw" { event_source_arn=aws_msk_cluster.this.arn
function_name=aws_lambda_function.consumer.arn
topics=["wsc2026-sensor-raw"]
starting_position="LATEST"
batch_size=100
enabled=true }
resource "aws_lambda_event_source_mapping" "alert" { event_source_arn=aws_msk_cluster.this.arn
function_name=aws_lambda_function.alert.arn
topics=["wsc2026-sensor-alert"]
starting_position="LATEST"
batch_size=100
enabled=true }

