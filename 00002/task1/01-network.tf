resource "aws_vpc" "main" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  tags = merge(var.tags, {
    Name = "wskorea26-vpc"
  })
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.tags, {
    Name = "book-igw"
  })
}
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.azs[count.index]
  cidr_block              = ["172.16.1.0/24", "172.16.2.0/24"][count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = ["wskorea26-pub-subnet-c", "wskorea26-pub-subnet-d"][count.index], "kubernetes.io/role/elb" = "1"
  })
}
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = ["172.16.201.0/24", "172.16.202.0/24"][count.index]
  tags = merge(var.tags, {
    Name = ["wskorea26-priv-subnet-c", "wskorea26-priv-subnet-d"][count.index], "kubernetes.io/role/internal-elb" = "1"
  })
}
resource "aws_eip" "nat" {
  count      = 2
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = merge(var.tags, {
    Name = "book-ngw-${count.index == 0 ? "c" : "d"}"
  })
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, {
    Name = "wskorea26-public-rtb"
  })
}
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  tags = merge(var.tags, {
    Name = "wskorea26-private-rtb-${count.index == 0 ? "c" : "d"}"
  })
}
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
resource "aws_security_group" "environment" {
  name   = "wskorea26-vpc-environment-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
    description = "EKS private endpoint access from the CloudShell VPC environment"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}
