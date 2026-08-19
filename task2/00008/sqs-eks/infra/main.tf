data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  cluster_name = "skills-sqs-cluster"
  subnets = {
    public-a  = { cidr = "10.84.1.0/24", az = "us-west-2a", public = true }
    public-b  = { cidr = "10.84.2.0/24", az = "us-west-2b", public = true }
    private-a = { cidr = "10.84.11.0/24", az = "us-west-2a", public = false }
    private-b = { cidr = "10.84.12.0/24", az = "us-west-2b", public = false }
  }
}
resource "aws_vpc" "main" {
  cidr_block           = "10.84.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name                                          = "skills-sqs-vpc"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "skills-sqs-igw" }
}
resource "aws_subnet" "this" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public
  tags = {
    Name                                                               = "skills-sqs-${each.key}-subnet"
    "kubernetes.io/cluster/${local.cluster_name}"                      = "shared"
    "kubernetes.io/role/${each.value.public ? "elb" : "internal-elb"}" = "1"
    "karpenter.sh/discovery"                                           = local.cluster_name
  }
}
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "skills-sqs-nat-eip" }
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.this["public-a"].id
  tags          = { Name = "skills-sqs-nat" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "skills-sqs-public-rt" }
}
resource "aws_route_table_association" "public" {
  for_each       = toset(["public-a", "public-b"])
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "skills-sqs-private-rt" }
}
resource "aws_route_table_association" "private" {
  for_each       = toset(["private-a", "private-b"])
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private.id
}

resource "aws_iam_role" "cluster" {
  name               = "skills-sqs-cluster-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_security_group" "cluster" {
  name   = "skills-sqs-cluster-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-sqs-cluster-sg" }
}
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = local.input.kubernetes_version
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  vpc_config {
    subnet_ids              = [for subnet in aws_subnet.this : subnet.id]
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = local.input.cluster_public_access_cidrs
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]
  tags       = { Name = local.cluster_name }
}

resource "aws_ec2_tag" "cluster_security_group_discovery" {
  resource_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

data "tls_certificate" "oidc" { url = aws_eks_cluster.main.identity[0].oidc[0].issuer }
resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}
locals {
  oidc_host = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}
resource "aws_iam_role" "fargate" {
  name               = "skills-sqs-fargate-pod-execution-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks-fargate-pods.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "fargate" {
  role       = aws_iam_role.fargate.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}
resource "aws_eks_fargate_profile" "keda" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "skills-sqs-fp-keda"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [aws_subnet.this["private-a"].id, aws_subnet.this["private-b"].id]
  selector { namespace = "keda" }
  depends_on = [aws_iam_role_policy_attachment.fargate]
}
resource "aws_eks_fargate_profile" "karpenter" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "skills-sqs-fp-karpenter"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [aws_subnet.this["private-a"].id, aws_subnet.this["private-b"].id]
  selector { namespace = "karpenter" }
  depends_on = [aws_iam_role_policy_attachment.fargate]
}
resource "aws_eks_fargate_profile" "coredns" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "skills-sqs-fp-coredns"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [aws_subnet.this["private-a"].id, aws_subnet.this["private-b"].id]
  selector {
    namespace = "kube-system"
    labels    = { "k8s-app" = "kube-dns" }
  }
  depends_on = [aws_iam_role_policy_attachment.fargate]
}

resource "aws_sqs_queue" "worker" {
  name                       = "skills-sqs-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  sqs_managed_sse_enabled    = true
  tags                       = { Name = "skills-sqs-queue" }
}
resource "aws_ecr_repository" "worker" {
  name                 = "skills-sqs-worker"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = local.input.cleanup_mode
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "skills-sqs-worker" }
}

resource "aws_iam_role" "keda" {
  name = "skills-sqs-keda-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }, Action = "sts:AssumeRoleWithWebIdentity",
    Condition = { StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com", "${local.oidc_host}:sub" = "system:serviceaccount:keda:keda-operator" } }
  }] })
}
resource "aws_iam_role_policy" "keda" {
  name   = "skills-sqs-keda-policy"
  role   = aws_iam_role.keda.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl"], Resource = aws_sqs_queue.worker.arn }] })
}
resource "aws_iam_role" "worker" {
  name = "skills-sqs-worker-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }, Action = "sts:AssumeRoleWithWebIdentity",
    Condition = { StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com", "${local.oidc_host}:sub" = "system:serviceaccount:skills-sqs:sqs-worker-sa" } }
  }] })
}
resource "aws_iam_role_policy" "worker" {
  name   = "skills-sqs-worker-policy"
  role   = aws_iam_role.worker.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility"], Resource = aws_sqs_queue.worker.arn }] })
}

resource "aws_iam_role" "node" {
  name               = "skills-sqs-karpenter-node-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly", "AmazonEKS_CNI_Policy", "AmazonSSMManagedInstanceCore"])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.key}"
}
resource "aws_eks_access_entry" "node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.node.arn
  type          = "EC2_LINUX"
}
resource "aws_iam_role" "karpenter" {
  name = "skills-sqs-karpenter-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }, Action = "sts:AssumeRoleWithWebIdentity",
    Condition = { StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com", "${local.oidc_host}:sub" = "system:serviceaccount:karpenter:karpenter" } }
  }] })
}
resource "aws_iam_role_policy" "karpenter" {
  name = "skills-sqs-karpenter-policy"
  role = aws_iam_role.karpenter.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ec2:CreateFleet", "ec2:RunInstances", "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:CreateTags", "ec2:TerminateInstances", "ec2:Describe*", "pricing:GetProducts", "ssm:GetParameter"], Resource = "*" },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.node.arn },
    { Effect = "Allow", Action = ["iam:GetRole"], Resource = aws_iam_role.node.arn },
    { Effect = "Allow", Action = ["iam:CreateInstanceProfile", "iam:TagInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile"], Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*" },
    { Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = aws_eks_cluster.main.arn }
  ] })
}

output "cluster_name" { value = aws_eks_cluster.main.name }
output "queue_url" { value = aws_sqs_queue.worker.url }
output "queue_arn" { value = aws_sqs_queue.worker.arn }
output "keda_role_arn" { value = aws_iam_role.keda.arn }
output "karpenter_role_arn" { value = aws_iam_role.karpenter.arn }
output "worker_role_arn" { value = aws_iam_role.worker.arn }
output "node_role_name" { value = aws_iam_role.node.name }
output "worker_repository_url" { value = aws_ecr_repository.worker.repository_url }
