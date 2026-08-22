data "aws_iam_policy_document" "eks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "eks" {
  name               = "wskorea26-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_trust.json
}
resource "aws_iam_role_policy_attachment" "eks" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_kms_key" "eks" {
  description             = "wskorea26 EKS secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}
resource "aws_kms_alias" "eks" {
  name          = "alias/wskorea26-eks-key"
  target_key_id = aws_kms_key.eks.key_id
}
resource "aws_eks_cluster" "main" {
  name                      = "wskorea26-cluster"
  role_arn                  = aws_iam_role.eks.arn
  version                   = local.input.cluster_version
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    security_group_ids      = [aws_security_group.environment.id]
    endpoint_private_access = true
    endpoint_public_access  = local.input.eks_endpoint_public_access
    public_access_cidrs     = local.input.eks_endpoint_public_access ? local.input.eks_public_access_cidrs : null
  }
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }
  depends_on = [aws_iam_role_policy_attachment.eks]
}
data "aws_iam_policy_document" "nodes_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "nodes" {
  name               = "wskorea26-node-role"
  assume_role_policy = data.aws_iam_policy_document.nodes_trust.json
}
resource "aws_iam_role_policy_attachment" "nodes" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonEC2ContainerRegistryReadOnly"])
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}
resource "aws_iam_role_policy" "nodes_book_data" {
  role = aws_iam_role.nodes.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.book.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.ddb.arn
      }
    ]
  })
}
resource "aws_eks_node_group" "node" {
  for_each = {
    addon = "wskorea26-addon-ng", app = "wskorea26-app-ng"
  }
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.value
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["t3.medium"]
  labels = {
    "node-type" = each.key
  }
  taint {
    key    = "node-type"
    value  = each.key
    effect = "NO_SCHEDULE"
  }
  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }
  tags = merge(local.input.tags, {
    Name = "wskorea26-${each.key}-node"
  })
  depends_on = [aws_iam_role_policy_attachment.nodes]
}
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  configuration_values = jsonencode({
    nodeSelector = {
      "node-type" = "addon"
      }, tolerations = [{
        key = "node-type", operator = "Equal", value = "addon", effect = "NoSchedule"
    }]
  })
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.node]
}

resource "aws_eks_access_entry" "additional_admin" {
  for_each = local.input.additional_cluster_admin_principal_arns

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "additional_admin" {
  for_each = local.input.additional_cluster_admin_principal_arns

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.additional_admin]
}
