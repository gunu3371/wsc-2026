resource "aws_vpc" "main" { cidr_block = "10.30.0.0/16"
enable_dns_support = true
enable_dns_hostnames = true
tags = { Name = "wsc2026-logging-vpc" } }
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id
tags = { Name = "wsc2026-logging-igw" } }
locals { subnets = { public-a = { cidr = "10.30.1.0/24", az = "ap-northeast-1a", public = true }, public-c = { cidr = "10.30.2.0/24", az = "ap-northeast-1c", public = true }, private-a = { cidr = "10.30.10.0/24", az = "ap-northeast-1a", public = false }, private-c = { cidr = "10.30.20.0/24", az = "ap-northeast-1c", public = false } } }
resource "aws_subnet" "main" { for_each = local.subnets
vpc_id = aws_vpc.main.id
cidr_block = each.value.cidr
availability_zone = each.value.az
map_public_ip_on_launch = each.value.public
tags = { Name = "wsc2026-${each.key}-subnet", "kubernetes.io/role/${each.value.public ? "elb" : "internal-elb"}" = "1" } }
resource "aws_eip" "nat" { for_each = toset(["a", "c"])
domain = "vpc"
depends_on = [aws_internet_gateway.main] }
resource "aws_nat_gateway" "main" { for_each = toset(["a", "c"])
allocation_id = aws_eip.nat[each.key].id
subnet_id = aws_subnet.main["public-${each.key}"].id
tags = { Name = "wsc2026-logging-nat-${each.key}" } }
resource "aws_route_table" "public" { vpc_id = aws_vpc.main.id
route { cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.main.id } }
resource "aws_route_table_association" "public" { for_each = toset(["a", "c"])
subnet_id = aws_subnet.main["public-${each.key}"].id
route_table_id = aws_route_table.public.id }
resource "aws_route_table" "private" { for_each = toset(["a", "c"])
vpc_id = aws_vpc.main.id
route { cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.main[each.key].id } }
resource "aws_route_table_association" "private" { for_each = toset(["a", "c"])
subnet_id = aws_subnet.main["private-${each.key}"].id
route_table_id = aws_route_table.private[each.key].id }

data "aws_iam_policy_document" "eks_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["eks.amazonaws.com"] } } }
resource "aws_iam_role" "eks" { name = "wsc2026-logging-cluster-role"
assume_role_policy = data.aws_iam_policy_document.eks_assume.json }
resource "aws_iam_role_policy_attachment" "eks" { role = aws_iam_role.eks.name
policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy" }
data "aws_iam_policy_document" "node_assume" { statement { actions = ["sts:AssumeRole"]
principals { type = "Service"
identifiers = ["ec2.amazonaws.com"] } } }
resource "aws_iam_role" "node" { name = "wsc2026-logging-node-role"
assume_role_policy = data.aws_iam_policy_document.node_assume.json }
resource "aws_iam_role_policy_attachment" "node" { for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
role = aws_iam_role.node.name
policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.key}" }
resource "aws_eks_cluster" "main" { name = "wsc2026-logging-cluster"
version = "1.35"
role_arn = aws_iam_role.eks.arn
vpc_config { subnet_ids = [for k, v in aws_subnet.main : v.id]
endpoint_public_access = true
endpoint_private_access = true }
depends_on = [aws_iam_role_policy_attachment.eks] }
resource "aws_eks_node_group" "main" { cluster_name = aws_eks_cluster.main.name
node_group_name = "wsc2026-logging-nodegroup"
node_role_arn = aws_iam_role.node.arn
subnet_ids = [aws_subnet.main["private-a"].id, aws_subnet.main["private-c"].id]
instance_types = ["t3.medium"]
ami_type = "AL2023_x86_64_STANDARD"
scaling_config { desired_size = 2
min_size = 2
max_size = 2 }
depends_on = [aws_iam_role_policy_attachment.node] }
output "cluster_name" { value = aws_eks_cluster.main.name }
