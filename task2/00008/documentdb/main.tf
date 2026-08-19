data "aws_partition" "current" {}
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.51.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "skills-nosql-vpc" }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "skills-nosql-igw" }
}
resource "aws_subnet" "client" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.51.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "skills-nosql-client-public-subnet" }
}
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.51.11.0/24"
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "skills-nosql-db-private-subnet-a" }
}
resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.51.12.0/24"
  availability_zone = "ap-northeast-2b"
  tags              = { Name = "skills-nosql-db-private-subnet-b" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "skills-nosql-public-rt" }
}
resource "aws_route_table_association" "client" {
  subnet_id      = aws_subnet.client.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "client" {
  name   = "skills-nosql-client-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.input.client_allowed_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-nosql-client-sg" }
}
resource "aws_security_group" "docdb" {
  name   = "skills-nosql-docdb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.client.id]
  }
  tags = { Name = "skills-nosql-docdb-sg" }
}

resource "aws_kms_key" "docdb" {
  description             = "skills-nosql DocumentDB encryption"
  enable_key_rotation     = true
  deletion_window_in_days = local.input.cleanup_mode ? 7 : 30
  tags                    = { Name = "skills-nosql-docdb" }
}
resource "aws_kms_alias" "docdb" {
  name          = "alias/skills-nosql-docdb"
  target_key_id = aws_kms_key.docdb.key_id
}
resource "random_password" "docdb" {
  length  = 32
  special = false
}
resource "aws_docdb_subnet_group" "main" {
  name       = "skills-nosql-docdb-subnet-group"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]
  tags       = { Name = "skills-nosql-docdb-subnet-group" }
}
resource "aws_docdb_cluster_parameter_group" "main" {
  family = "docdb5.0"
  name   = "skills-nosql-docdb-params"
  parameter {
    name  = "tls"
    value = "enabled"
  }
}
resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "skills-nosql-docdb-cluster"
  engine                          = "docdb"
  master_username                 = "skillsadmin"
  master_password                 = random_password.docdb.result
  backup_retention_period         = 7
  preferred_backup_window         = "18:00-19:00"
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.docdb.arn
  skip_final_snapshot             = local.input.cleanup_mode || local.input.skip_final_snapshot
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]
  tags                            = { Name = "skills-nosql-docdb-cluster" }
}
resource "aws_docdb_cluster_instance" "main" {
  identifier         = "skills-nosql-docdb-instance-1"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"
  engine             = "docdb"
  tags               = { Name = "skills-nosql-docdb-instance-1" }
}

resource "aws_secretsmanager_secret" "docdb" {
  name                    = "skills-nosql-docdb-secret"
  kms_key_id              = aws_kms_key.docdb.arn
  recovery_window_in_days = local.input.cleanup_mode ? 0 : 30
  tags                    = { Name = "skills-nosql-docdb-secret" }
}
resource "aws_secretsmanager_secret_version" "docdb" {
  secret_id = aws_secretsmanager_secret.docdb.id
  secret_string = jsonencode({
    username = aws_docdb_cluster.main.master_username
    password = random_password.docdb.result
    host     = aws_docdb_cluster.main.endpoint
  })
}

resource "aws_iam_role" "client" {
  name = "skills-nosql-client-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "client" {
  name = "skills-nosql-client-policy"
  role = aws_iam_role.client.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.docdb.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.docdb.arn
      }
    ]
  })
}
resource "aws_iam_instance_profile" "client" {
  name = "skills-nosql-client-profile"
  role = aws_iam_role.client.name
}

resource "aws_instance" "client" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.client.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.client.id]
  iam_instance_profile        = aws_iam_instance_profile.client.name
  user_data_replace_on_change = true
  # EC2 user-data has a 16 KiB API limit; cloud-init transparently expands gzip input.
  user_data_base64 = base64gzip(templatefile("${path.module}/../assets/documentdb/user-data.sh.tftpl", {
    client_source = base64encode(file("${path.module}/../assets/documentdb/docdb_client.py"))
    dataset       = base64encode(file("${path.module}/../assets/documentdb/retail_dataset.json"))
  }))
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }
  tags       = { Name = "skills-nosql-client-ec2" }
  depends_on = [aws_docdb_cluster_instance.main, aws_secretsmanager_secret_version.docdb]
}

output "client_public_ip" { value = aws_instance.client.public_ip }
output "docdb_endpoint" { value = aws_docdb_cluster.main.endpoint }

