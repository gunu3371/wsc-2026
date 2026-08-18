data "aws_ssm_parameter" "al2023" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }
data "aws_eks_cluster" "target" { name = var.cluster_name }
data "aws_kms_alias" "static_bucket" { name = "alias/wsc2026-bucket-kms" }
data "aws_kms_alias" "grading_read" {
  for_each = toset([
    "alias/wsc2026-db-kms",
    "alias/wsc2026-ecr-kms",
    "alias/wsc2026-eks-kms",
    "alias/wsc2026-function-kms",
  ])
  name = each.value
}

resource "aws_iam_role" "ssm" {
  name               = "wsc2026-grading-bastion-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "grading" {
  name = "wsc2026-grading-bastion-access"
  role = aws_iam_role.ssm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["eks:DescribeCluster", "eks:AccessKubernetesApi", "eks:CreatePodIdentityAssociation", "eks:ListPodIdentityAssociations"], Resource = "arn:aws:eks:${var.region}:*:cluster/${var.cluster_name}" },
      { Effect = "Allow", Action = ["eks:DescribePodIdentityAssociation", "eks:DeletePodIdentityAssociation"], Resource = "arn:aws:eks:${var.region}:*:podidentityassociation/${var.cluster_name}/*" },
      { Effect = "Allow", Action = ["ec2:DescribeManagedPrefixLists", "ec2:GetManagedPrefixListEntries"], Resource = "*" },
      { Effect = "Allow", Action = ["ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:CreateTags", "ec2:DescribeSecurityGroups", "ec2:DescribeNetworkInterfaces"], Resource = "*" },
      { Effect = "Allow", Action = ["dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups", "dynamodb:DescribeTimeToLive", "dynamodb:ListTagsOfResource"], Resource = "arn:aws:dynamodb:${var.region}:*:table/wsc2026-book-table" },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole", "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PassRole", "iam:CreateOpenIDConnectProvider", "iam:GetOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider"], Resource = "*" },
      { Effect = "Allow", Action = ["iam:CreatePolicyVersion", "iam:DeletePolicyVersion"], Resource = "arn:aws:iam::*:policy/wsc2026-book-pod-policy" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"], Resource = "arn:aws:ecr:${var.region}:*:repository/wsc2026-book-ecr" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "arn:aws:s3:::wsc2026-static-*-00003-bucket/grading/*" },
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::wsc2026-static-*-00003-bucket/static/*" },
      { Effect = "Allow", Action = ["ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeInternetGateways", "ec2:DescribeNatGateways", "ec2:DescribeRouteTables", "ecr:DescribeRepositories", "ecr:ListImages", "eks:DescribeNodegroup", "kms:DescribeKey", "kms:GetKeyPolicy", "dynamodb:GetResourcePolicy", "s3:ListAllMyBuckets", "s3:GetBucketPublicAccessBlock", "s3:GetEncryptionConfiguration", "s3:ListBucket", "s3:GetObjectAttributes", "lambda:GetFunction", "elasticloadbalancing:DescribeLoadBalancers", "iam:ListAttachedRolePolicies", "iam:GetPolicy", "iam:GetPolicyVersion", "tag:GetResources", "cloudfront:GetDistribution", "wafv2:ListWebACLs", "wafv2:GetWebACL"], Resource = "*" }
    ]
  })
}
resource "aws_iam_instance_profile" "ssm" {
  name = "wsc2026-grading-bastion-profile"
  role = aws_iam_role.ssm.name
}
resource "aws_security_group" "bastion" {
  name   = "wsc2026-grading-bastion-sg"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "wsc2026-grading-bastion-sg", ManagedBy = "Terraform", Project = "wsc2026" }
}
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_bastion" {
  security_group_id            = data.aws_eks_cluster.target.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "SSM grading bastion to private EKS API"
}
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.ssm.arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.ssm.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
  depends_on = [aws_eks_access_entry.bastion]
}
resource "aws_kms_grant" "static_bucket_read" {
  name              = "wsc2026-grading-bastion-static-read"
  key_id            = data.aws_kms_alias.static_bucket.target_key_arn
  grantee_principal = aws_iam_role.ssm.arn
  operations        = ["Decrypt", "DescribeKey"]
}
resource "aws_kms_grant" "grading_read" {
  for_each          = data.aws_kms_alias.grading_read
  name              = "wsc2026-grading-bastion-${replace(each.key, "alias/", "")}-read"
  key_id            = each.value.target_key_arn
  grantee_principal = aws_iam_role.ssm.arn
  operations        = ["DescribeKey"]
}
resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  user_data              = <<-EOF
    #!/bin/bash
    dnf install -y docker git jq
    systemctl enable --now docker
    curl -Lo /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.35.0/2025-01-10/bin/linux/amd64/kubectl
    chmod +x /usr/local/bin/kubectl
  EOF
  tags                   = { Name = "wsc2026-grading-bastion", ManagedBy = "Terraform", Project = "wsc2026" }
}
