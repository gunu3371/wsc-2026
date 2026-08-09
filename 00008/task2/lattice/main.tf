data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
data "aws_ec2_managed_prefix_list" "lattice" {
  name = "com.amazonaws.ap-northeast-1.vpc-lattice"
}

resource "aws_vpc" "client" {
  cidr_block           = "10.61.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "skills-lattice-client-vpc" }
}
resource "aws_vpc" "service" {
  cidr_block           = "10.62.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "skills-lattice-service-vpc" }
}
resource "aws_internet_gateway" "client" {
  vpc_id = aws_vpc.client.id
  tags   = { Name = "skills-lattice-client-igw" }
}
resource "aws_subnet" "client" {
  vpc_id                  = aws_vpc.client.id
  cidr_block              = "10.61.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "skills-lattice-client-public-subnet" }
}
resource "aws_subnet" "service" {
  vpc_id                  = aws_vpc.service.id
  cidr_block              = "10.62.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
  tags                    = { Name = "skills-lattice-service-private-subnet" }
}
resource "aws_route_table" "client" {
  vpc_id = aws_vpc.client.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.client.id
  }
  tags = { Name = "skills-lattice-client-public-rt" }
}
resource "aws_route_table_association" "client" {
  subnet_id      = aws_subnet.client.id
  route_table_id = aws_route_table.client.id
}

resource "aws_security_group" "client" {
  name   = "skills-lattice-client-sg"
  vpc_id = aws_vpc.client.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.client_allowed_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-lattice-client-sg" }
}
resource "aws_security_group" "service" {
  name   = "skills-lattice-service-sg"
  vpc_id = aws_vpc.service.id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.lattice.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-lattice-service-sg" }
}
resource "aws_security_group" "association" {
  name   = "skills-lattice-association-sg"
  vpc_id = aws_vpc.client.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.client.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-lattice-association-sg" }
}

resource "aws_vpclattice_service_network" "main" {
  name      = "skills-lattice-sn"
  auth_type = "NONE"
  tags      = { Name = "skills-lattice-sn" }
}
resource "aws_vpclattice_service" "orders" {
  name      = "skills-lattice-order-service"
  auth_type = "NONE"
  tags      = { Name = "skills-lattice-order-service" }
}
resource "aws_vpclattice_service_network_service_association" "orders" {
  service_identifier         = aws_vpclattice_service.orders.id
  service_network_identifier = aws_vpclattice_service_network.main.id
}
resource "aws_vpclattice_service_network_vpc_association" "client" {
  service_network_identifier = aws_vpclattice_service_network.main.id
  vpc_identifier             = aws_vpc.client.id
  security_group_ids         = [aws_security_group.association.id]
  tags                       = { Name = "skills-lattice-client-association" }
}

resource "aws_instance" "service" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.service.id
  vpc_security_group_ids = [aws_security_group.service.id]
  user_data = templatefile("${path.module}/service-user-data.sh.tftpl", {
    service_app = base64encode(file("${path.module}/assets/service_app.py"))
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device { encrypted = true }
  tags = { Name = "skills-lattice-service-ec2" }
}

resource "aws_vpclattice_target_group" "orders" {
  name = "skills-lattice-order-tg"
  type = "INSTANCE"
  config {
    port             = 8080
    protocol         = "HTTP"
    protocol_version = "HTTP1"
    vpc_identifier   = aws_vpc.service.id
    health_check {
      enabled                       = true
      health_check_interval_seconds = 30
      health_check_timeout_seconds  = 5
      healthy_threshold_count       = 2
      unhealthy_threshold_count     = 2
      matcher { value = "200" }
      path     = "/health"
      port     = 8080
      protocol = "HTTP"
    }
  }
  tags = { Name = "skills-lattice-order-tg" }
}
resource "aws_vpclattice_target_group_attachment" "service" {
  target_group_identifier = aws_vpclattice_target_group.orders.id
  target {
    id   = aws_instance.service.id
    port = 8080
  }
}
resource "aws_vpclattice_listener" "http" {
  name               = "skills-lattice-http-listener"
  service_identifier = aws_vpclattice_service.orders.id
  protocol           = "HTTP"
  port               = 80
  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.orders.id
        weight                  = 100
      }
    }
  }
  tags = { Name = "skills-lattice-http-listener" }
}

resource "aws_instance" "client" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.client.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.client.id]
  user_data = templatefile("${path.module}/client-user-data.sh.tftpl", {
    client_app  = base64encode(file("${path.module}/assets/client_app.py"))
    service_url = "http://${aws_vpclattice_service.orders.dns_entry[0].domain_name}"
  })
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device { encrypted = true }
  tags = { Name = "skills-lattice-client-ec2" }
  depends_on = [aws_vpclattice_service_network_vpc_association.client, aws_vpclattice_listener.http]
}

variable "client_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
output "service_domain" { value = aws_vpclattice_service.orders.dns_entry[0].domain_name }
output "client_public_ip" { value = aws_instance.client.public_ip }

