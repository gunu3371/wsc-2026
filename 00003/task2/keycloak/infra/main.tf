resource "aws_vpc" "main" { cidr_block = "10.20.0.0/16"
enable_dns_support = true
enable_dns_hostnames = true
tags = { Name = "wsc2026-keycloak-vpc" } }
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id
tags = { Name = "wsc2026-keycloak-igw" } }
resource "aws_subnet" "public" { for_each = { a = { cidr = "10.20.1.0/24", az = data.aws_availability_zones.available.names[0] }, b = { cidr = "10.20.2.0/24", az = data.aws_availability_zones.available.names[1] } }
vpc_id = aws_vpc.main.id
cidr_block = each.value.cidr
availability_zone = each.value.az
map_public_ip_on_launch = true
tags = { Name = "wsc2026-public-subnet-${each.key}" } }
resource "aws_subnet" "private" { vpc_id = aws_vpc.main.id
cidr_block = "10.20.10.0/24"
availability_zone = data.aws_availability_zones.available.names[0]
tags = { Name = "wsc2026-private-subnet-a" } }
resource "aws_eip" "nat" { domain = "vpc"
depends_on = [aws_internet_gateway.main] }
resource "aws_nat_gateway" "main" { allocation_id = aws_eip.nat.id
subnet_id = aws_subnet.public["a"].id
tags = { Name = "wsc2026-keycloak-nat" } }
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id
route { cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.main.id } }
resource "aws_route_table_association" "public" { for_each = aws_subnet.public
subnet_id = each.value.id
route_table_id = aws_route_table.public.id }
resource "aws_route_table" "private" { vpc_id = aws_vpc.main.id
route { cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.main.id } }
resource "aws_route_table_association" "private" { subnet_id = aws_subnet.private.id
route_table_id = aws_route_table.private.id }

resource "aws_security_group" "alb" { name = "wsc2026-keycloak-alb-sg"
vpc_id = aws_vpc.main.id
ingress { from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"] }
egress { from_port = 8080
to_port = 8080
protocol = "tcp"
cidr_blocks = [aws_vpc.main.cidr_block] }
egress { from_port = 9000
to_port = 9000
protocol = "tcp"
cidr_blocks = [aws_vpc.main.cidr_block] }
tags = { Name = "wsc2026-keycloak-alb-sg" } }
resource "aws_security_group" "keycloak" { name = "wsc2026-keycloak-sg"
vpc_id = aws_vpc.main.id
ingress { from_port = 8080
to_port = 8080
protocol = "tcp"
security_groups = [aws_security_group.alb.id] }
ingress { from_port = 9000
to_port = 9000
protocol = "tcp"
security_groups = [aws_security_group.alb.id] }
egress { from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"] }
tags = { Name = "wsc2026-keycloak-sg" } }

data "aws_iam_policy_document" "ec2_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["ec2.amazonaws.com"] } } }
resource "aws_iam_role" "ec2" { name = "wsc2026-keycloak-ec2-role"
assume_role_policy = data.aws_iam_policy_document.ec2_assume.json }
resource "aws_iam_role_policy_attachment" "ssm" { role = aws_iam_role.ec2.name
policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_iam_instance_profile" "ec2" { name = "wsc2026-keycloak-ec2-profile"
role = aws_iam_role.ec2.name }
resource "aws_instance" "keycloak" { ami = data.aws_ssm_parameter.al2023.value
instance_type = "t3.medium"
subnet_id = aws_subnet.private.id
associate_public_ip_address = false
vpc_security_group_ids = [aws_security_group.keycloak.id]
iam_instance_profile = aws_iam_instance_profile.ec2.name
user_data = templatefile("${path.module}/assets/user-data.sh.tftpl", { password = var.keycloak_admin_password })
user_data_replace_on_change = true
metadata_options { http_tokens = "required"
http_endpoint = "enabled" }
root_block_device { encrypted = true
volume_type = "gp3" }
tags = { Name = "wsc2026-keycloak" } }
resource "aws_lb" "main" { name = "wsc2026-keycloak-alb"
internal = false
load_balancer_type = "application"
security_groups = [aws_security_group.alb.id]
subnets = values(aws_subnet.public)[*].id }
resource "aws_lb_target_group" "main" { name = "wsc2026-keycloak-tg"
port = 8080
protocol = "HTTP"
vpc_id = aws_vpc.main.id
health_check { path = "/health/ready"
port = "9000"
matcher = "200" } }
resource "aws_lb_target_group_attachment" "main" { target_group_arn = aws_lb_target_group.main.arn
target_id = aws_instance.keycloak.id
port = 8080 }
resource "aws_lb_listener" "http" { load_balancer_arn = aws_lb.main.arn
port = 80
protocol = "HTTP"
default_action { type = "forward"
target_group_arn = aws_lb_target_group.main.arn } }

resource "aws_iam_saml_provider" "keycloak" { count = var.saml_metadata_document == null ? 0 : 1
name = "wsc2026-keycloak-idp"
saml_metadata_document = var.saml_metadata_document }
data "aws_iam_policy_document" "saml_assume" { count = var.saml_metadata_document == null ? 0 : 1
statement { actions = ["sts:AssumeRoleWithSAML"]
principals { type = "Federated"
identifiers = [aws_iam_saml_provider.keycloak[0].arn] }
condition { test = "StringEquals"
variable = "SAML:aud"
values = ["https://signin.aws.amazon.com/saml"] } } }
resource "aws_iam_role" "saml" { for_each = var.saml_metadata_document == null ? {} : { dev = "wsc2026-dev-role", infra = "wsc2026-infra-role" }
name = each.value
assume_role_policy = data.aws_iam_policy_document.saml_assume[0].json
max_session_duration = 3600 }
resource "aws_iam_policy" "dev" { count = var.saml_metadata_document == null ? 0 : 1
name = "wsc2026-dev-policy"
policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["ec2:Describe*", "s3:Get*", "s3:List*"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = "ap-northeast-2" } } }] }) }
resource "aws_iam_policy" "infra" { count = var.saml_metadata_document == null ? 0 : 1
name = "wsc2026-infra-policy"
policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["ec2:Describe*", "s3:Get*", "s3:List*", "iam:Get*", "iam:List*"], Resource = "*" }, { Effect = "Allow", Action = ["ec2:StartInstances", "ec2:StopInstances"], Resource = "*" }, { Effect = "Deny", Action = ["ec2:StartInstances", "ec2:StopInstances"], Resource = "*", Condition = { StringEquals = { "ec2:ResourceTag/protected" = "true" } } }] }) }
resource "aws_iam_role_policy_attachment" "saml" { for_each = var.saml_metadata_document == null ? {} : { dev = aws_iam_policy.dev[0].arn, infra = aws_iam_policy.infra[0].arn }
role = aws_iam_role.saml[each.key].name
policy_arn = each.value }
output "keycloak_url" { value = "http://${aws_lb.main.dns_name}" }
output "saml_role_arns" { value = { for k, v in aws_iam_role.saml : k => v.arn } }
