data "aws_caller_identity" "current" {}
data "aws_eks_cluster" "target" { name = "skills-sqs-cluster" }
data "aws_kms_key" "documentdb" {
  provider = aws.ap_northeast_2
  key_id   = "alias/skills-nosql-docdb"
}
data "aws_vpc" "target" {
  filter {
    name   = "tag:Name"
    values = ["skills-sqs-vpc"]
  }
}
data "aws_subnet" "target" {
  filter {
    name   = "tag:Name"
    values = ["skills-sqs-public-a-subnet"]
  }
}
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ssm" {
  name               = "skills-sqs-grading-bastion-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "grading_mutations" {
  name = "skills-sqs-grading-test-actions"
  role = aws_iam_role.ssm.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:skills-nosql-docdb-secret-*" },
    { Effect = "Allow", Action = ["kms:Decrypt"], Resource = data.aws_kms_key.documentdb.arn },
    { Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = "arn:aws:lambda:ap-southeast-1:${data.aws_caller_identity.current.account_id}:function:skills-ceh-remediate-fn" },
    { Effect = "Allow", Action = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"], Resource = "arn:aws:ec2:ap-southeast-1:${data.aws_caller_identity.current.account_id}:security-group/*", Condition = { StringEquals = { "ec2:ResourceTag/Name" = "skills-ceh-protected-sg" } } },
    { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:skills-sqs-queue" },
    { Effect = "Allow", Action = ["rds:DescribeDBClusters", "rds:DescribeDBInstances", "kms:DescribeKey", "secretsmanager:DescribeSecret", "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeInstances", "ec2:DescribeSecurityGroups", "vpc-lattice:ListServiceNetworks", "vpc-lattice:ListServices", "vpc-lattice:ListTargetGroups", "vpc-lattice:ListServiceNetworkVpcAssociations", "vpc-lattice:GetServiceNetworkVpcAssociation", "vpc-lattice:ListServiceNetworkServiceAssociations", "vpc-lattice:ListTargets", "vpc-lattice:ListListeners", "sns:ListTopics", "lambda:GetFunctionConfiguration", "lambda:GetPolicy", "cloudtrail:GetTrailStatus", "events:DescribeRule", "events:ListTargetsByRule", "logs:DescribeLogGroups", "eks:DescribeCluster", "eks:DescribeFargateProfile", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"], Resource = "*" }
  ] })
}
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = data.aws_eks_cluster.target.name
  principal_arn = aws_iam_role.ssm.arn
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = data.aws_eks_cluster.target.name
  principal_arn = aws_iam_role.ssm.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"
  access_scope { type = "cluster" }
  depends_on = [aws_eks_access_entry.bastion]
}
resource "aws_kms_grant" "documentdb_secret_read" {
  provider          = aws.ap_northeast_2
  name              = "skills-sqs-grading-bastion-documentdb-secret-read"
  key_id            = data.aws_kms_key.documentdb.arn
  grantee_principal = aws_iam_role.ssm.arn
  operations        = ["Decrypt", "DescribeKey"]
}
resource "aws_iam_role_policy" "ecr_push" {
  name = "skills-sqs-worker-ecr-push"
  role = aws_iam_role.ssm.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"], Resource = "arn:aws:ecr:us-west-2:${data.aws_caller_identity.current.account_id}:repository/skills-sqs-worker" }
  ] })
}
resource "aws_iam_instance_profile" "ssm" {
  name = "skills-sqs-grading-bastion-profile"
  role = aws_iam_role.ssm.name
}
resource "aws_security_group" "bastion" {
  name        = "skills-sqs-grading-bastion-sg"
  description = "Outbound-only SSM build bastion"
  vpc_id      = data.aws_vpc.target.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "skills-sqs-grading-bastion-sg", ManagedBy = "Terraform", TaskId = "00008" }
}
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_bastion" {
  security_group_id            = data.aws_eks_cluster.target.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "SSM grading bastion to private EKS API"
}
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.target.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = true
  user_data                   = <<-EOT
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
  EOT
  tags                        = { Name = "skills-sqs-grading-bastion", ManagedBy = "Terraform", TaskId = "00008" }
}
