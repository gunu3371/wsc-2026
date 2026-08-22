data "aws_iam_policy_document" "book_pod_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "book_pod" {
  name               = "wsc2026-book-pod-role"
  assume_role_policy = data.aws_iam_policy_document.book_pod_assume.json
}

resource "aws_iam_policy" "book_pod" {
  name = "wsc2026-book-pod-policy"
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
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.main["db"].arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "book_pod" {
  role       = aws_iam_role.book_pod.name
  policy_arn = aws_iam_policy.book_pod.arn
}
