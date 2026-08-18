resource "kubernetes_namespace_v1" "book" {
  metadata {
    name = "wsc2026"
  }
}
resource "kubernetes_service_account_v1" "book" {
  metadata {
    name      = "wsc2026-book-sa"
    namespace = kubernetes_namespace_v1.book.metadata[0].name
  }
}
resource "kubernetes_config_map_v1" "book" {
  metadata {
    name      = "book-config"
    namespace = kubernetes_namespace_v1.book.metadata[0].name
  }
  data = {
    AWS_REGION = var.region, TABLE_NAME = var.table_name
  }
}

resource "aws_iam_role" "lbc" {
  name               = "wsc2026-load-balancer-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
}
resource "aws_iam_policy" "lbc" {
  name = "wsc2026-load-balancer-controller-policy"
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["ec2:Describe*", "ec2:CreateSecurityGroup", "ec2:CreateTags", "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup", "elasticloadbalancing:*", "iam:CreateServiceLinkedRole", "acm:ListCertificates", "acm:DescribeCertificate", "wafv2:GetWebACLForResource", "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL", "shield:GetSubscriptionState", "shield:DescribeProtection", "shield:CreateProtection", "shield:DeleteProtection"], Resource = "*"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}
resource "kubernetes_service_account_v1" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lbc.arn
    }
  }
}
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.15.0"
  values = [yamlencode({
    clusterName = var.cluster_name, region = var.region, vpcId = var.vpc_id, serviceAccount = {
      create = false, name = kubernetes_service_account_v1.lbc.metadata[0].name
    }
  })]
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
resource "aws_security_group" "alb" {
  name   = "wsc2026-app-alb-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "wsc2026-app-alb-sg"
  }
}

resource "kubernetes_deployment_v1" "book" {
  depends_on = [aws_eks_pod_identity_association.book]

  metadata {
    name      = "wsc2026-book-deploy"
    namespace = kubernetes_namespace_v1.book.metadata[0].name
    labels = {
      app = "wsc2026-book"
    }
  }
  spec {

    replicas = 2
    selector {
      match_labels = {
        app = "wsc2026-book"
      }
    }
    template {

      metadata {
        labels = {
          app = "wsc2026-book"
        }
        annotations = {
          "wsc2026/pod-identity-association" = aws_eks_pod_identity_association.book.association_id
        }
      }
      spec {

        service_account_name = kubernetes_service_account_v1.book.metadata[0].name
        node_selector = {
          "wsc2026/node" = "application"
        }
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = {
              app = "wsc2026-book"
            }
          }
        }
        container {

          name              = "book"
          image             = var.image_uri
          image_pull_policy = "IfNotPresent"
          port {
            name           = "http"
            container_port = 8080
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.book.metadata[0].name
            }
          }
          resources {
            requests = {
              cpu = "250m", memory = "512Mi"
            }
            limits = {
              cpu = "250m", memory = "512Mi"
            }
          }
          startup_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            failure_threshold = 30
            period_seconds    = 5
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            period_seconds = 5
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            period_seconds = 10
          }

        }

      }

    }

  }

}

resource "kubernetes_service_v1" "book" {
  metadata {
    name      = "wsc2026-book-svc"
    namespace = kubernetes_namespace_v1.book.metadata[0].name
  }
  spec {
    selector = {
      app = "wsc2026-book"
    }
    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
    internal_traffic_policy = "Local"
  }
}
resource "kubernetes_pod_disruption_budget_v1" "book" {
  metadata {
    name      = "wsc2026-book-pdb"
    namespace = kubernetes_namespace_v1.book.metadata[0].name
  }
  spec {
    min_available = "1"
    selector {
      match_labels = {
        app = "wsc2026-book"
      }
    }
  }
}
resource "kubernetes_ingress_v1" "book" {

  metadata {
    name      = "wsc2026-book-ingress"
    namespace = kubernetes_namespace_v1.book.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name"                  = "wsc2026-app-alb"
      "alb.ingress.kubernetes.io/scheme"                              = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"                         = "ip"
      "alb.ingress.kubernetes.io/listen-ports"                        = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path"                    = "/health"
      "alb.ingress.kubernetes.io/security-groups"                     = aws_security_group.alb.id
      "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "true"
      "alb.ingress.kubernetes.io/tags"                                = join(",", [for key, value in local.ingress_tags : "${key}=${value}"])
      "alb.ingress.kubernetes.io/transforms.wsc2026-book-svc" = jsonencode([{
        type = "url-rewrite"
        urlRewriteConfig = {
          rewrites = [{ regex = "^/booking$", replace = "/v1/book" }]
        }
      }])
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/booking"
          path_type = "Exact"
          backend {
            service {
              name = kubernetes_service_v1.book.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.lbc]

}

output "alb_hostname" {
  value = try(kubernetes_ingress_v1.book.status[0].load_balancer[0].ingress[0].hostname, null)
}
