resource "kubernetes_service_v1" "fluentbit_metrics" {
  metadata {
    name      = "unicorn-fluent-bit-metrics"
    namespace = kubernetes_namespace_v1.unicorn.metadata[0].name
    labels = {
      app = "unicorn-fluent-bit-metrics"
    }
  }
  spec {
    selector = {
      app = "unicorn-fluent-bit"
    }
    port {
      name        = "metrics"
      port        = 2021
      target_port = "metrics"
    }
  }
}

resource "kubernetes_manifest" "fluentbit_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "unicorn-fluent-bit-metrics"
      namespace = "monitoring"
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      namespaceSelector = {
        matchNames = [kubernetes_namespace_v1.unicorn.metadata[0].name]
      }
      selector = {
        matchLabels = {
          app = "unicorn-fluent-bit-metrics"
        }
      }
      endpoints = [{
        port     = "metrics"
        path     = "/metrics"
        interval = "15s"
      }]
    }
  }
  depends_on = [helm_release.monitoring, kubernetes_service_v1.fluentbit_metrics]
}

resource "aws_security_group" "grafana_alb" {
  name   = "unicorn-grafana-alb-sg"
  vpc_id = local.input.vpc_id

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

resource "aws_security_group_rule" "grafana_alb_to_nodes" {
  type                     = "ingress"
  from_port                = 30030
  to_port                  = 30030
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana_alb.id
  security_group_id        = local.input.cluster_security_group_id
}

resource "aws_lb" "grafana" {
  name               = "unicorn-grafana-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = local.input.public_subnet_ids
  security_groups    = [aws_security_group.grafana_alb.id]
}

resource "aws_lb_target_group" "grafana" {
  name     = "unicorn-grafana-tg"
  port     = 30030
  protocol = "HTTP"
  vpc_id   = local.input.vpc_id

  health_check {
    path    = "/api/health"
    matcher = "200"
  }
}

data "aws_instances" "addon" {
  filter {
    name   = "tag:Name"
    values = ["unicorn-k8snode-addon-node"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

resource "aws_lb_target_group_attachment" "grafana" {
  for_each         = toset(data.aws_instances.addon.ids)
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = each.value
  port             = 30030
  depends_on       = [helm_release.monitoring]
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
