terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" }
 kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.36" } }
}
provider "aws" { region = "ap-northeast-1" }
data "aws_availability_zones" "available" { state = "available" }
data "aws_partition" "current" {}
variable "log_generator_image" { type = string
 description = "Published Module4 image URI" }
variable "kubernetes_version" { type = string
 default = "1.35" }

resource "aws_vpc" "main" { cidr_block = "10.84.0.0/16"
 enable_dns_hostnames = true
 tags = { Name = "o11y-vpc" } }
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_subnet" "public" { count = 2
 vpc_id = aws_vpc.main.id
 cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
 availability_zone = data.aws_availability_zones.available.names[count.index]
 map_public_ip_on_launch = true
 tags = { Name = "o11y-public-${count.index + 1}", "kubernetes.io/role/elb" = "1" } }
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id
 route { cidr_block = "0.0.0.0/0"
 gateway_id = aws_internet_gateway.main.id } }
resource "aws_route_table_association" "public" { count = 2
 subnet_id = aws_subnet.public[count.index].id
 route_table_id = aws_route_table.public.id }
resource "aws_security_group" "nodes" { name = "o11y-node-sg"
 vpc_id = aws_vpc.main.id
 ingress { from_port = 0
 to_port = 0
 protocol = "-1"
 self = true }
 ingress { from_port = 30000
 to_port = 32767
 protocol = "tcp"
 cidr_blocks = [aws_vpc.main.cidr_block] }
 egress { from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_iam_role" "cluster" { name = "o11y-cluster-role"
 assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = ["sts:AssumeRole", "sts:TagSession"] }] }) }
resource "aws_iam_role_policy_attachment" "cluster" { role = aws_iam_role.cluster.name
 policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy" }
resource "aws_eks_cluster" "main" { name = "o11y-cluster"
 version = var.kubernetes_version
 role_arn = aws_iam_role.cluster.arn
 vpc_config { subnet_ids = aws_subnet.public[*].id
 security_group_ids = [aws_security_group.nodes.id]
 endpoint_public_access = true
 endpoint_private_access = true }
 access_config { authentication_mode = "API_AND_CONFIG_MAP"
 bootstrap_cluster_creator_admin_permissions = true }
 depends_on = [aws_iam_role_policy_attachment.cluster] }
resource "aws_iam_role" "node" { name = "o11y-node-role"
 assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] }) }
resource "aws_iam_role_policy_attachment" "node" { for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
 role = aws_iam_role.node.name
 policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}" }
resource "aws_eks_node_group" "main" { cluster_name = aws_eks_cluster.main.name
 node_group_name = "o11y-node-group"
 node_role_arn = aws_iam_role.node.arn
 subnet_ids = aws_subnet.public[*].id
 instance_types = ["t3.medium"]
 scaling_config { min_size = 2
 desired_size = 2
 max_size = 2 }
 update_config { max_unavailable = 1 }
 labels = { timezone = "Asia-Seoul" }
 tags = { Name = "o11y-node" }
 depends_on = [aws_iam_role_policy_attachment.node] }
resource "aws_eks_addon" "pod_identity" { cluster_name = aws_eks_cluster.main.name
 addon_name = "eks-pod-identity-agent"
 depends_on = [aws_eks_node_group.main] }
resource "aws_iam_role" "ebs" { name = "o11y-ebs-csi-role"
 assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "pods.eks.amazonaws.com" }, Action = ["sts:AssumeRole", "sts:TagSession"] }] }) }
resource "aws_iam_role_policy_attachment" "ebs" { role = aws_iam_role.ebs.name
 policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" }
resource "aws_eks_addon" "ebs" { cluster_name = aws_eks_cluster.main.name
 addon_name = "aws-ebs-csi-driver"
 pod_identity_association { service_account = "ebs-csi-controller-sa"
  role_arn = aws_iam_role.ebs.arn }
 depends_on = [aws_eks_addon.pod_identity, aws_iam_role_policy_attachment.ebs] }
data "aws_eks_cluster_auth" "main" { name = aws_eks_cluster.main.name }
provider "kubernetes" { host = aws_eks_cluster.main.endpoint
 cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
 token = data.aws_eks_cluster_auth.main.token }
resource "kubernetes_namespace_v1" "app" { metadata { name = "o11y" }
 depends_on = [aws_eks_node_group.main] }
resource "kubernetes_namespace_v1" "monitoring" { metadata { name = "monitoring" }
 depends_on = [aws_eks_node_group.main] }
resource "kubernetes_deployment_v1" "app" { metadata { name = "log-generator"
 namespace = "o11y"
 labels = { app = "log-generator" } }
 spec { replicas = 2
 selector { match_labels = { app = "log-generator" } }
 template { metadata { labels = { app = "log-generator" } }
 spec { container { name = "log-generator"
 image = var.log_generator_image
 port { container_port = 8080 }
 readiness_probe { http_get { path = "/healthz"
 port = 8080 } } } } } } }
resource "kubernetes_service_v1" "app" { metadata { name = "log-generator"
 namespace = "o11y" }
 spec { selector = { app = "log-generator" }
 type = "NodePort"
 port { port = 80
 target_port = "8080"
 node_port = 30080 } } }

resource "kubernetes_config_map_v1" "loki" { metadata { name = "o11y-loki-config"
 namespace = "monitoring" }
 data = { "config.yaml" = file("${path.module}/assets/loki.yaml") } }
resource "kubernetes_persistent_volume_claim_v1" "loki" { metadata { name = "o11y-loki-data"
 namespace = "monitoring" }
 spec { access_modes = ["ReadWriteOnce"]
 resources { requests = { storage = "10Gi" } } } }
resource "kubernetes_deployment_v1" "loki" { metadata { name = "o11y-loki"
 namespace = "monitoring"
 labels = { app = "o11y-loki" } }
 spec { replicas = 1
 selector { match_labels = { app = "o11y-loki" } }
 template { metadata { labels = { app = "o11y-loki" } }
 spec { container { name = "loki"
 image = "grafana/loki:3.5.3"
 args = ["-config.file=/etc/loki/config.yaml"]
 port { container_port = 3100 }
 volume_mount { name = "config"
 mount_path = "/etc/loki" }
 volume_mount { name = "data"
 mount_path = "/loki" } }
 volume { name = "config"
 config_map { name = kubernetes_config_map_v1.loki.metadata[0].name } }
 volume { name = "data"
 persistent_volume_claim { claim_name = kubernetes_persistent_volume_claim_v1.loki.metadata[0].name } } } } } }
resource "kubernetes_service_v1" "loki" { metadata { name = "o11y-loki"
 namespace = "monitoring" }
 spec { selector = { app = "o11y-loki" }
 port { port = 3100
 target_port = "3100" } } }
resource "kubernetes_service_account_v1" "otel" { metadata { name = "o11y-otel"
 namespace = "monitoring" } }
resource "kubernetes_cluster_role_v1" "otel" { metadata { name = "o11y-otel" }
 rule { api_groups = [""]
 resources = ["pods", "namespaces", "nodes"]
 verbs = ["get", "list", "watch"] } }
resource "kubernetes_cluster_role_binding_v1" "otel" { metadata { name = "o11y-otel" }
 role_ref { api_group = "rbac.authorization.k8s.io"
 kind = "ClusterRole"
 name = kubernetes_cluster_role_v1.otel.metadata[0].name }
 subject { kind = "ServiceAccount"
 name = "o11y-otel"
 namespace = "monitoring" } }
resource "kubernetes_config_map_v1" "otel" { metadata { name = "o11y-otel-config"
 namespace = "monitoring" }
 data = { "config.yaml" = file("${path.module}/assets/otel.yaml") } }
resource "kubernetes_daemon_set_v1" "otel" { metadata { name = "o11y-otel"
 namespace = "monitoring"
 labels = { app = "o11y-otel" } }
 spec { selector { match_labels = { app = "o11y-otel" } }
 template { metadata { labels = { app = "o11y-otel" } }
 spec { service_account_name = "o11y-otel"
 container { name = "otel"
 image = "otel/opentelemetry-collector-contrib:0.131.1"
 args = ["--config=/etc/otel/config.yaml"]
 env { name = "K8S_NODE_NAME"
 value_from { field_ref { field_path = "spec.nodeName" } } }
 volume_mount { name = "config"
 mount_path = "/etc/otel" }
 volume_mount { name = "varlogpods"
 mount_path = "/var/log/pods"
 read_only = true } }
 volume { name = "config"
 config_map { name = "o11y-otel-config" } }
 volume { name = "varlogpods"
 host_path { path = "/var/log/pods" } } } } }
 depends_on = [kubernetes_cluster_role_binding_v1.otel, kubernetes_deployment_v1.loki] }

resource "kubernetes_config_map_v1" "grafana" { metadata { name = "o11y-grafana-provisioning"
 namespace = "monitoring" }
 data = { "datasource.yaml" = file("${path.module}/assets/datasource.yaml"), "dashboard-provider.yaml" = file("${path.module}/assets/dashboard-provider.yaml"), "log-overview.json" = file("${path.module}/assets/log-overview.json") } }
resource "kubernetes_deployment_v1" "grafana" { metadata { name = "o11y-grafana"
 namespace = "monitoring"
 labels = { app = "o11y-grafana" } }
 spec { replicas = 1
 selector { match_labels = { app = "o11y-grafana" } }
 template { metadata { labels = { app = "o11y-grafana" } }
 spec { container { name = "grafana"
 image = "grafana/grafana:12.0.2"
 port { container_port = 3000 }
 env { name = "GF_AUTH_ANONYMOUS_ENABLED"
 value = "true" }
 env { name = "GF_AUTH_ANONYMOUS_ORG_ROLE"
 value = "Viewer" }
 volume_mount { name = "provisioning"
 mount_path = "/etc/grafana/provisioning/datasources/datasource.yaml"
 sub_path = "datasource.yaml" }
 volume_mount { name = "provisioning"
 mount_path = "/etc/grafana/provisioning/dashboards/provider.yaml"
 sub_path = "dashboard-provider.yaml" }
 volume_mount { name = "provisioning"
 mount_path = "/var/lib/grafana/dashboards/log-overview.json"
 sub_path = "log-overview.json" } }
 volume { name = "provisioning"
 config_map { name = "o11y-grafana-provisioning" } } } } } }
resource "kubernetes_service_v1" "grafana" { metadata { name = "o11y-grafana"
 namespace = "monitoring" }
 spec { selector = { app = "o11y-grafana" }
 type = "NodePort"
 port { port = 3000
 target_port = "3000"
 node_port = 30300 } } }

resource "aws_security_group" "alb" { name = "o11y-alb-sg"
 vpc_id = aws_vpc.main.id
 ingress { from_port = 80
 to_port = 80
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"] }
 egress { from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"] } }
resource "aws_security_group_rule" "alb_app_nodes" { type = "ingress"
 from_port = 30080
 to_port = 30080
 protocol = "tcp"
 source_security_group_id = aws_security_group.alb.id
 security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id }
resource "aws_security_group_rule" "alb_grafana_nodes" { type = "ingress"
 from_port = 30300
 to_port = 30300
 protocol = "tcp"
 source_security_group_id = aws_security_group.alb.id
 security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id }
resource "aws_lb" "app" { name = "o11y-app-alb"
 load_balancer_type = "application"
 internal = false
 subnets = aws_subnet.public[*].id
 security_groups = [aws_security_group.alb.id] }
resource "aws_lb_target_group" "app" { name = "o11y-app-tg"
 port = 30080
 protocol = "HTTP"
 vpc_id = aws_vpc.main.id
 health_check { path = "/healthz"
 matcher = "200" } }
resource "aws_lb_listener" "app" { load_balancer_arn = aws_lb.app.arn
 port = 80
 protocol = "HTTP"
 default_action { type = "forward"
 target_group_arn = aws_lb_target_group.app.arn } }
resource "aws_lb" "grafana" { name = "o11y-grafana-alb"
 load_balancer_type = "application"
 internal = false
 subnets = aws_subnet.public[*].id
 security_groups = [aws_security_group.alb.id] }
resource "aws_lb_target_group" "grafana" { name = "o11y-grafana-tg"
 port = 30300
 protocol = "HTTP"
 vpc_id = aws_vpc.main.id
 health_check { path = "/api/health"
 matcher = "200" } }
resource "aws_lb_listener" "grafana" { load_balancer_arn = aws_lb.grafana.arn
 port = 80
 protocol = "HTTP"
 default_action { type = "forward"
 target_group_arn = aws_lb_target_group.grafana.arn } }
data "aws_instances" "nodes" { filter { name = "tag:eks:cluster-name"
 values = [aws_eks_cluster.main.name] }
 filter { name = "instance-state-name"
 values = ["running"] }
 depends_on = [aws_eks_node_group.main] }
resource "aws_lb_target_group_attachment" "app" { for_each = toset(data.aws_instances.nodes.ids)
 target_group_arn = aws_lb_target_group.app.arn
 target_id = each.value
 port = 30080
 depends_on = [kubernetes_service_v1.app] }
resource "aws_lb_target_group_attachment" "grafana" { for_each = toset(data.aws_instances.nodes.ids)
 target_group_arn = aws_lb_target_group.grafana.arn
 target_id = each.value
 port = 30300
 depends_on = [kubernetes_service_v1.grafana] }
output "app_url" { value = "http://${aws_lb.app.dns_name}" }
output "grafana_url" { value = "http://${aws_lb.grafana.dns_name}" }
