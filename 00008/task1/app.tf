resource "aws_kms_key" "ddb" {
  description             = "skills-book DynamoDB encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = { Name = "skills-book-ddb" }
}
resource "aws_kms_alias" "ddb" {
  name          = "alias/skills-book-ddb"
  target_key_id = aws_kms_key.ddb.key_id
}
resource "aws_dynamodb_table" "booking" {
  name         = "skills-book-booking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "booking_id"
  attribute {
    name = "booking_id"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.ddb.arn
  }
  point_in_time_recovery { enabled = true }
  tags = { Name = "skills-book-booking" }
}
resource "aws_ecr_repository" "book" {
  name                 = "skills-book-ecr"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = { Name = "skills-book-ecr" }
}
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/skills-book-app"
  retention_in_days = 30
  tags              = { Name = "skills-book-app" }
}

resource "aws_iam_role" "execution" {
  name = "skills-book-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "task" {
  name = "skills-book-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy" "task" {
  name = "skills-book-ecs-task-policy"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
      Resource = aws_dynamodb_table.booking.arn
    }]
  })
}

resource "aws_ecs_cluster" "book" {
  name = "skills-book-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Name = "skills-book-cluster" }
}
locals {
  image_uri = coalesce(var.image_uri, "${aws_ecr_repository.book.repository_url}:latest")
}
resource "aws_ecs_task_definition" "book" {
  family                   = "skills-book-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions = jsonencode([{
    name      = "skills-book-container"
    image     = local.image_uri
    essential = true
    portMappings = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "AWS_REGION", value = "ap-northeast-2" },
      { name = "TABLE_NAME", value = aws_dynamodb_table.booking.name }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = "ap-northeast-2"
        awslogs-stream-prefix = "book"
      }
    }
  }])
  tags = { Name = "skills-book-task" }
}

resource "aws_security_group" "alb" {
  name   = "skills-book-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  tags = { Name = "skills-book-alb-sg" }
}
resource "aws_security_group" "ecs" {
  name   = "skills-book-ecs-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-book-ecs-sg" }
}
resource "aws_lb" "book" {
  name               = "skills-book-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.this["public-a"].id, aws_subnet.this["public-b"].id]
  tags               = { Name = "skills-book-alb" }
}
resource "aws_lb_target_group" "book" {
  name        = "skills-book-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "skills-book-tg" }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.book.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":\"forbidden\"}"
      status_code  = "403"
    }
  }
}
resource "aws_lb_listener_rule" "cloudfront" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.book.arn
  }
  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [var.origin_verify_secret]
    }
  }
}
resource "aws_ecs_service" "book" {
  name            = "skills-book-service"
  cluster         = aws_ecs_cluster.book.id
  task_definition = aws_ecs_task_definition.book.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.this["private-a"].id, aws_subnet.this["private-b"].id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.book.arn
    container_name   = "skills-book-container"
    container_port   = 8080
  }
  health_check_grace_period_seconds = 60
  depends_on = [aws_lb_listener_rule.cloudfront, aws_iam_role_policy.task]
  tags       = { Name = "skills-book-service" }
}
