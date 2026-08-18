resource "aws_lb" "this" {
  name               = "wsc2026-analytics-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}
resource "aws_lb_target_group" "this" {
  name     = "wsc2026-analytics-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    path    = "/health"
    matcher = "200"
  }
}
resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.app.id
  port             = 5000
}
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

