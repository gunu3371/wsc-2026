data "aws_iam_policy_document" "assume_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "wskorea26-grading-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "push_image" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [data.aws_ecr_repository.book.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.build_artifacts.arn}/private-build/grading-bastion/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.s3.target_key_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:ap-northeast-2:${data.aws_caller_identity.current.account_id}:cluster/wskorea26-cluster"]
  }
}

resource "aws_iam_role_policy" "push_image" {
  name   = "wskorea26-grading-bastion-push-image"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.push_image.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "wskorea26-grading-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_security_group" "bastion" {
  name        = "wskorea26-grading-bastion-sg"
  description = "No ingress; outbound access only for one-time ECR image push"
  vpc_id      = data.aws_subnet.private_d.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.private_d.id
  vpc_security_group_ids      = [aws_security_group.bastion.id, data.aws_security_group.eks_environment.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "wskorea26-grading-bastion"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.push_image,
    aws_s3_object.dockerfile,
    aws_s3_object.book_binary,
  ]
}

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = "wskorea26-cluster"
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = "wskorea26-cluster"
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}
