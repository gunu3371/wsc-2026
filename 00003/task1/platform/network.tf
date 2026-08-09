resource "aws_vpc" "main" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "wsc2026-skills-vpc" }
}

resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id
tags = { Name = "wsc2026-skills-igw" } }

resource "aws_subnet" "public" {
  for_each = { a = { cidr = "192.168.1.0/24", az = local.azs[0] }, b = { cidr = "192.168.10.0/24", az = local.azs[1] } }
  vpc_id = aws_vpc.main.id
cidr_block = each.value.cidr
availability_zone = each.value.az
map_public_ip_on_launch = true
  tags = { Name = "wsc2026-skills-hub-sub-${each.key}", "kubernetes.io/role/elb" = "1" }
}

resource "aws_subnet" "private" {
  for_each = { a = { cidr = "192.168.2.0/24", az = local.azs[0] }, b = { cidr = "192.168.20.0/24", az = local.azs[1] } }
  vpc_id = aws_vpc.main.id
cidr_block = each.value.cidr
availability_zone = each.value.az
  tags = { Name = "wsc2026-skills-app-sub-${each.key}", "kubernetes.io/role/internal-elb" = "1" }
}

resource "aws_eip" "nat" { for_each = aws_subnet.public
domain = "vpc"
tags = { Name = "wsc2026-skills-nat-eip-${each.key}" }
depends_on = [aws_internet_gateway.main] }
resource "aws_nat_gateway" "main" { for_each = aws_subnet.public
allocation_id = aws_eip.nat[each.key].id
subnet_id = each.value.id
tags = { Name = "wsc2026-skills-nat-${each.key}" }
depends_on = [aws_internet_gateway.main] }

resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id
route { cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.main.id }
tags = { Name = "wsc2026-skills-hub-rtb" } }
resource "aws_route_table_association" "public" { for_each = aws_subnet.public
subnet_id = each.value.id
route_table_id = aws_route_table.public.id }
resource "aws_route_table" "private" { for_each = aws_subnet.private
vpc_id = aws_vpc.main.id
route { cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.main[each.key].id }
tags = { Name = "wsc2026-skills-app-rtb-${each.key}" } }
resource "aws_route_table_association" "private" { for_each = aws_subnet.private
subnet_id = each.value.id
route_table_id = aws_route_table.private[each.key].id }
