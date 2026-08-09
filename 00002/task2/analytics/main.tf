locals { az=["a","c"]
 public=["10.20.1.0/24","10.20.2.0/24"]
 private=["10.20.101.0/24","10.20.102.0/24"] }
resource "aws_vpc" "this" { cidr_block="10.20.0.0/16"
 enable_dns_support=true
 enable_dns_hostnames=true
 tags={Name="analytics-vpc"} }
resource "aws_internet_gateway" "this" { vpc_id=aws_vpc.this.id
 tags={Name="analytics-igw"} }
resource "aws_subnet" "public" { count=2
 vpc_id=aws_vpc.this.id
 cidr_block=local.public[count.index]
 availability_zone=var.availability_zones[count.index]
 map_public_ip_on_launch=true
 tags={Name="wsc2026-analytics-public-${local.az[count.index]}"} }
resource "aws_subnet" "private" { count=2
 vpc_id=aws_vpc.this.id
 cidr_block=local.private[count.index]
 availability_zone=var.availability_zones[count.index]
 tags={Name="wsc2026-analytics-private-${local.az[count.index]}"} }
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
resource "aws_security_group" "alb" { name="wsc2026-analytics-alb-sg"
 vpc_id=aws_vpc.this.id
 ingress {from_port=80
to_port=80
protocol="tcp"
cidr_blocks=[var.allowed_cidr]}
 egress {from_port=0
to_port=0
protocol="-1"
cidr_blocks=["0.0.0.0/0"]} }
resource "aws_security_group" "ec2" { name="wsc2026-analytics-ec2-sg"
 vpc_id=aws_vpc.this.id
 ingress {from_port=5000
to_port=5000
protocol="tcp"
security_groups=[aws_security_group.alb.id]}
 egress {from_port=0
to_port=0
protocol="-1"
cidr_blocks=["0.0.0.0/0"]} }

resource "aws_kinesis_stream" "orders" { name="wsc2026-order-stream"
 stream_mode_details {stream_mode="ON_DEMAND"}
 encryption_type="KMS"
 kms_key_id="alias/aws/kinesis" }
resource "aws_iam_role" "ec2" { name="wsc2026-analytics-ec2-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="ec2.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy_attachment" "ssm" { role=aws_iam_role.ec2.name
 policy_arn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_iam_role_policy" "kinesis" { role=aws_iam_role.ec2.id
 policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["kinesis:PutRecord","kinesis:PutRecords"],Resource=aws_kinesis_stream.orders.arn}]}) }
resource "aws_iam_instance_profile" "ec2" { name="wsc2026-analytics-ec2-profile"
 role=aws_iam_role.ec2.name }
data "aws_ssm_parameter" "ami" { name="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
resource "aws_instance" "app" { ami=data.aws_ssm_parameter.ami.value
 instance_type="t3.small"
 subnet_id=aws_subnet.private[0].id
 vpc_security_group_ids=[aws_security_group.ec2.id]
 iam_instance_profile=aws_iam_instance_profile.ec2.name
 user_data=templatefile("${path.module}/user_data.sh.tftpl",{app=base64encode(file("${path.module}/app.py")),requirements=base64encode(file("${path.module}/requirements.txt")),region="ap-northeast-2",stream=aws_kinesis_stream.orders.name})
 tags={Name="wsc2026-analytics-ec2"} }
resource "aws_lb" "this" { name="wsc2026-analytics-alb"
 load_balancer_type="application"
 internal=false
 security_groups=[aws_security_group.alb.id]
 subnets=aws_subnet.public[*].id }
resource "aws_lb_target_group" "this" { name="wsc2026-analytics-tg"
 port=5000
 protocol="HTTP"
 vpc_id=aws_vpc.this.id
 health_check {path="/health"
matcher="200"} }
resource "aws_lb_target_group_attachment" "this" { target_group_arn=aws_lb_target_group.this.arn
 target_id=aws_instance.app.id
 port=5000 }
resource "aws_lb_listener" "this" { load_balancer_arn=aws_lb.this.arn
 port=80
 protocol="HTTP"
 default_action {type="forward"
target_group_arn=aws_lb_target_group.this.arn} }

resource "aws_iam_role" "flink" { name="wsc2026-analytics-flink-role"
 assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="kinesisanalytics.amazonaws.com"},Action="sts:AssumeRole"}]}) }
resource "aws_iam_role_policy" "flink" { role=aws_iam_role.flink.id
 policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Action=["kinesis:DescribeStreamSummary","kinesis:GetRecords","kinesis:GetShardIterator","kinesis:ListShards"],Resource=aws_kinesis_stream.orders.arn},{Effect="Allow",Action=["logs:*"],Resource="*"}]}) }
resource "aws_kinesisanalyticsv2_application" "flink" { name="wsc2026-analytics-flink"
 runtime_environment="FLINK-1_19"
 service_execution_role=aws_iam_role.flink.arn
 application_mode="INTERACTIVE"
 application_configuration { zeppelin_application_configuration { monitoring_configuration {log_level="INFO"} } } }

