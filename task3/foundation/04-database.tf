resource "aws_security_group" "rds" {
  name        = "${local.input.project_name}-rds"
  description = "MySQL access from the EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EKS cluster security group"
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.input.project_name}-rds-sg" }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.input.project_name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-=?_"
}

resource "aws_db_instance" "main" {
  identifier = "apdev-rds-instance"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  multi_az       = true

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "dev"
  username = local.input.db_username
  password = random_password.db.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.input.project_name}/database"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = local.input.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}
