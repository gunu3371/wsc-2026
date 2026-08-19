terraform {

  required_version = ">= 1.6.0"
  required_providers {

    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes", version = "~> 2.36"
    }
    helm = {
      source = "hashicorp/helm", version = "~> 3.0"
    }

  }

}
provider "aws" {
  region = "ap-northeast-2"
}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_caller_identity" "current" {

}
data "aws_partition" "current" {

}


resource "aws_vpc" "main" {
  cidr_block           = "10.83.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "skm-vpc"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "skm-igw"
  }
}
resource "aws_subnet" "public" {

  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "skm-public-${count.index + 1}", "kubernetes.io/role/elb" = "1", "karpenter.sh/discovery" = "skm-eks-cluster"
  }

}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_sqs_queue" "orders" {
  name                       = "skm-order-queue"
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 30
}

resource "aws_iam_role" "cluster" {
  name = "skm-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "eks.amazonaws.com"
      }, Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_eks_cluster" "main" {

  name     = "skm-eks-cluster"
  version  = local.input.kubernetes_version
  role_arn = aws_iam_role.cluster.arn
  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = true
  }
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]

}
resource "aws_iam_role" "node" {
  name = "skm-addon-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}
resource "aws_launch_template" "addon" {

  name = "skm-cluster-addon-ng"
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "skm-cluster-addon-ng-node"
    }
  }

}
resource "aws_eks_node_group" "addon" {

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "skm-cluster-addon-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = ["t3.medium"]
  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 1
  }
  labels = {
    workload = "addons"
  }
  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  launch_template {
    id      = aws_launch_template.addon.id
    version = aws_launch_template.addon.latest_version
  }
  tags = {
    Name = "skm-cluster-addon-ng-node"
  }
  depends_on = [aws_iam_role_policy_attachment.node]

}
resource "aws_eks_addon" "pod_identity" {

  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  depends_on   = [aws_eks_node_group.addon]

}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

resource "aws_iam_role" "karpenter_controller" {

  name = "skm-karpenter-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "pods.eks.amazonaws.com"
      }, Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

}
resource "aws_iam_role_policy" "karpenter_controller" {

  role = aws_iam_role.karpenter_controller.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["ec2:CreateFleet", "ec2:CreateLaunchTemplate", "ec2:Describe*", "ec2:RunInstances", "ec2:TerminateInstances", "ec2:CreateTags", "pricing:GetProducts", "ssm:GetParameter", "sqs:GetQueueUrl", "sqs:ReceiveMessage", "sqs:DeleteMessage"], Resource = "*"
      },
      {
        Effect = "Allow", Action = "iam:PassRole", Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = aws_eks_cluster.main.arn
      }
    ]
  })

}
resource "aws_iam_role" "karpenter_node" {
  name               = "skm-karpenter-node-role"
  assume_role_policy = aws_iam_role.node.assume_role_policy
}
resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy", "AmazonSSMManagedInstanceCore"])
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}
resource "aws_eks_access_entry" "karpenter" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}
resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn
  depends_on      = [aws_eks_addon.pod_identity]
}

resource "helm_release" "karpenter" {

  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.8.1"
  wait       = true
  values = [yamlencode({
    settings = {
      clusterName = aws_eks_cluster.main.name
      }, serviceAccount = {
      name = "karpenter"
      }, tolerations = [{
        key = "CriticalAddonsOnly", operator = "Exists"
    }]
  })]
  depends_on = [aws_eks_node_group.addon, aws_eks_pod_identity_association.karpenter]

}
resource "kubernetes_manifest" "nodeclass" {

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1", kind = "EC2NodeClass", metadata = {
      name = "skm-app-nodeclass"
      }, spec = {
      role = aws_iam_role.karpenter_node.name, amiSelectorTerms = [{
        alias = "al2023@latest"
        }], subnetSelectorTerms = [{
        tags = {
          "karpenter.sh/discovery" = aws_eks_cluster.main.name
        }
        }], securityGroupSelectorTerms = [{
        tags = {
          "aws:eks:cluster-name" = aws_eks_cluster.main.name
        }
        }], tags = {
        Name = "skm-app-node"
      }
    }
  }
  depends_on = [helm_release.karpenter]

}
resource "kubernetes_manifest" "nodepool" {

  manifest = {
    apiVersion = "karpenter.sh/v1", kind = "NodePool", metadata = {
      name = "skm-app-nodepool"
      }, spec = {
      template = {
        metadata = {
          labels = {
            workload = "apps"
          }
          }, spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws", kind = "EC2NodeClass", name = "skm-app-nodeclass"
            }, taints = [{
              key = "skillsmkt/app", value = "true", effect = "NoSchedule"
              }], requirements = [{
              key = "node.kubernetes.io/instance-type", operator = "In", values = ["t3.small", "t3.medium"]
              }, {
              key = "kubernetes.io/arch", operator = "In", values = ["amd64"]
              }, {
              key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"]
          }]
        }
        }, limits = {
        cpu = "10"
        }, disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized", consolidateAfter = "60s"
      }
    }
  }
  depends_on = [kubernetes_manifest.nodeclass]

}
resource "aws_iam_role" "processor" {
  name               = "skm-order-processor-role"
  assume_role_policy = aws_iam_role.karpenter_controller.assume_role_policy
}
resource "aws_iam_role_policy" "processor" {
  role = aws_iam_role.processor.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility"], Resource = aws_sqs_queue.orders.arn
    }]
  })
}
resource "kubernetes_namespace_v1" "skillsmkt" {
  metadata {
    name = "skillsmkt"
  }
  depends_on = [aws_eks_node_group.addon]
}
resource "kubernetes_service_account_v1" "processor" {
  metadata {
    name      = "order-processor"
    namespace = kubernetes_namespace_v1.skillsmkt.metadata[0].name
  }
}
resource "aws_eks_pod_identity_association" "processor" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "skillsmkt"
  service_account = kubernetes_service_account_v1.processor.metadata[0].name
  role_arn        = aws_iam_role.processor.arn
}
resource "kubernetes_deployment_v1" "processor" {

  metadata {
    name      = "order-processor"
    namespace = "skillsmkt"
    labels = {
      app = "order-processor"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "order-processor"
      }
    }
    template {
      metadata {
        labels = {
          app = "order-processor"
        }
      }
      spec {
        service_account_name = "order-processor"
        node_selector = {
          workload = "apps"
        }
        toleration {
          key      = "skillsmkt/app"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }
        container {
          name  = "order-processor"
          image = local.input.order_processor_image
          port {
            container_port = 8080
          }
          env {
            name  = "SQS_QUEUE_URL"
            value = aws_sqs_queue.orders.url
          }
          env {
            name  = "AWS_REGION"
            value = "ap-northeast-2"
          }
          env {
            name  = "PROCESSING_TIME"
            value = "3"
          }
          resources {
            requests = {
              cpu = "500m", memory = "512Mi"
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_manifest.nodepool, aws_eks_pod_identity_association.processor]

}
resource "helm_release" "keda" {
  name             = "keda"
  namespace        = "keda"
  create_namespace = true
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = "2.18.3"
  values = [yamlencode({
    tolerations = [{
      key = "CriticalAddonsOnly", operator = "Exists"
      }], operator = {
      tolerations = [{
        key = "CriticalAddonsOnly", operator = "Exists"
      }]
      }, metricsServer = {
      tolerations = [{
        key = "CriticalAddonsOnly", operator = "Exists"
      }]
      }, webhooks = {
      tolerations = [{
        key = "CriticalAddonsOnly", operator = "Exists"
      }]
    }
  })]
  depends_on = [aws_eks_node_group.addon]
}
resource "aws_iam_role" "keda" {

  name               = "skm-keda-operator-role"
  assume_role_policy = aws_iam_role.karpenter_controller.assume_role_policy

}
resource "aws_iam_role_policy" "keda" {

  role = aws_iam_role.keda.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl"], Resource = aws_sqs_queue.orders.arn
    }]
  })

}
resource "aws_eks_pod_identity_association" "keda" {

  cluster_name    = aws_eks_cluster.main.name
  namespace       = "keda"
  service_account = "keda-operator"
  role_arn        = aws_iam_role.keda.arn
  depends_on      = [helm_release.keda]

}
resource "kubernetes_manifest" "scaler" {

  manifest = {
    apiVersion = "keda.sh/v1alpha1", kind = "ScaledObject", metadata = {
      name = "order-scaler", namespace = "skillsmkt"
      }, spec = {
      scaleTargetRef = {
        name = "order-processor"
        }, minReplicaCount = 1, maxReplicaCount = 5, pollingInterval = 5, cooldownPeriod = 30, triggers = [{
          type = "aws-sqs-queue", metadata = {
            queueURL = aws_sqs_queue.orders.url, queueLength = "5", awsRegion = "ap-northeast-2", identityOwner = "operator"
          }
      }]
    }
  }
  depends_on = [helm_release.keda, aws_eks_pod_identity_association.keda, kubernetes_deployment_v1.processor]

}
output "cluster_name" {
  value = aws_eks_cluster.main.name
}
output "queue_url" {
  value = aws_sqs_queue.orders.url
}
