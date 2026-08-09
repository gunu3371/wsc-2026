data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  subnets = {
    public-a  = { cidr = "10.20.1.0/24", az = "ap-northeast-2a", public = true }
    public-b  = { cidr = "10.20.2.0/24", az = "ap-northeast-2b", public = true }
    private-a = { cidr = "10.20.11.0/24", az = "ap-northeast-2a", public = false }
    private-b = { cidr = "10.20.12.0/24", az = "ap-northeast-2b", public = false }
  }
}
resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "skills-book-vpc" }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "skills-book-igw" }
}
resource "aws_subnet" "this" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public
  tags                    = { Name = "skills-book-${each.key}-subnet" }
}
resource "aws_eip" "nat" {
  for_each   = toset(["a", "b"])
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "skills-book-nat-${each.key}-eip" }
}
resource "aws_nat_gateway" "this" {
  for_each      = toset(["a", "b"])
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this["public-${each.key}"].id
  depends_on    = [aws_internet_gateway.main]
  tags          = { Name = "skills-book-nat-${each.key}" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "skills-book-public-rt" }
}
resource "aws_route_table_association" "public" {
  for_each       = toset(["public-a", "public-b"])
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  for_each = toset(["a", "b"])
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }
  tags = { Name = "skills-book-private-${each.key}-rt" }
}
resource "aws_route_table_association" "private" {
  for_each       = toset(["a", "b"])
  subnet_id      = aws_subnet.this["private-${each.key}"].id
  route_table_id = aws_route_table.private[each.key].id
}
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-2.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
  tags              = { Name = "skills-book-dynamodb-endpoint" }
}

