resource "aws_security_group" "alb" {
  name   = "wskorea26-book-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_lb" "book" {
  name               = "wskorea26-book-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_target_group" "lambda" {
  name        = "wskorea26-book-lambda-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group" "book" {
  name        = "wskorea26-book-tg"
  port        = 30080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled = true
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_autoscaling_attachment" "book" {
  autoscaling_group_name = aws_eks_node_group.node["app"].resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.book.arn
}

resource "aws_vpc_security_group_ingress_rule" "book_nodes" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 30080
  to_port                      = 30080
  ip_protocol                  = "tcp"
  description                  = "Book NodePort from the public ALB"
}
resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.book.arn
  depends_on       = [aws_lambda_permission.alb]
}
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.book.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.book.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}
resource "aws_lb_listener_rule" "book" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.book.arn
  }

  condition {
    path_pattern {
      values = ["/book*"]
    }
  }

  condition {
    http_request_method {
      values = ["POST"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = ["wskorea26-cf"]
    }
  }

  transform {
    type = "url-rewrite"

    url_rewrite_config {
      rewrite {
        regex   = "^/book$"
        replace = "/v1/book"
      }
    }
  }
}

resource "aws_lb_listener_rule" "book_query" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }
  condition {
    path_pattern {
      values = ["/book*"]
    }
  }
  condition {
    http_request_method {
      values = ["GET"]
    }
  }
  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = ["wskorea26-cf"]
    }
  }
}

