data "aws_caller_identity" "current" {}

data "aws_subnet" "private_d" {
  filter {
    name   = "tag:Name"
    values = ["wskorea26-priv-subnet-d"]
  }
}

data "aws_s3_bucket" "build_artifacts" {
  bucket = "wskorea26-concert-bucket-${local.input.task_id}"
}

data "aws_ecr_repository" "book" {
  name = "wskorea26-book-repo"
}

data "aws_kms_alias" "s3" {
  name = "alias/wskorea26-s3-key"
}

data "aws_security_group" "eks_client" {
  filter {
    name   = "group-name"
    values = ["wskorea26-cloudshell-sg"]
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
