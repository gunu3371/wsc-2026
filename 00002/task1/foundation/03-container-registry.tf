resource "aws_kms_key" "ecr" {
  description             = "wskorea26 ECR"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_ecr_repository" "book" {
  name = "wskorea26-book-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
  force_delete = true
}
