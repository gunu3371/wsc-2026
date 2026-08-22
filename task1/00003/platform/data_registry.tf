resource "aws_dynamodb_table" "book" {

  name                        = "wsc2026-book-table"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "client_id"
  deletion_protection_enabled = !local.input.cleanup_mode
  attribute {
    name = "client_id"
    type = "S"
  }
  attribute {
    name = "booking_id"
    type = "S"
  }
  global_secondary_index {
    name            = "booking_id-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "booking_id"
      key_type       = "HASH"
    }
  }
  point_in_time_recovery {
    enabled                 = true
    recovery_period_in_days = 35
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main["db"].arn
  }

}

resource "aws_ecr_repository" "book" {

  name                 = "wsc2026-book-ecr"
  image_tag_mutability = "MUTABLE_WITH_EXCLUSION"
  force_delete         = local.input.cleanup_mode
  image_tag_mutability_exclusion_filter {
    filter      = "v1*"
    filter_type = "WILDCARD"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main["ecr"].arn
  }

}

resource "aws_dynamodb_resource_policy" "book" {
  resource_arn = aws_dynamodb_table.book.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "BookPodPutItem"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.book_pod.arn }
        Action    = ["dynamodb:PutItem"]
        Resource  = aws_dynamodb_table.book.arn
      },
      {
        Sid       = "BookFunctionQuery"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.book_function.arn }
        Action    = ["dynamodb:Query"]
        Resource  = "${aws_dynamodb_table.book.arn}/index/booking_id-index"
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "book" {

  repository = aws_ecr_repository.book.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1, description = "keep only v1.0.0", selection = {
        tagStatus = "tagged", tagPrefixList = ["v"], countType = "imageCountMoreThan", countNumber = 1
        }, action = {
        type = "expire"
      }
    }]
  })

}
