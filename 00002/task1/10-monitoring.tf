resource "aws_lb" "grafana" {
  name               = "wskorea26-grafana-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_target_group" "grafana" {
  name     = "wskorea26-grafana-tg"
  port     = 30030
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path    = "/login"
    matcher = "200-399"
  }
}
resource "aws_autoscaling_attachment" "grafana" {
  autoscaling_group_name = aws_eks_node_group.node["addon"].resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.grafana.arn
}
resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.grafana.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}
resource "aws_vpc_security_group_ingress_rule" "grafana_nodes" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 30030
  to_port                      = 30030
  ip_protocol                  = "tcp"
  description                  = "Grafana NodePort from the public ALB"
}

