resource "aws_kms_key" "ddb" {
  description             = "wskorea26 DynamoDB"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}
resource "aws_kms_alias" "ddb" {
  name          = "alias/wskorea26-dynamodb-key"
  target_key_id = aws_kms_key.ddb.key_id
}
resource "aws_dynamodb_table" "book" {
  name         = "wskorea26-data-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "client_id"
  attribute {
    name = "client_id"
    type = "S"
  }
  attribute {
    name = "concert_name"
    type = "S"
  }
  attribute {
    name = "created_at"
    type = "S"
  }
  global_secondary_index {
    name = "concert_name-created_at-index"
    key_schema {
      attribute_name = "concert_name"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "created_at"
      key_type       = "RANGE"
    }
    projection_type = "ALL"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.ddb.arn
  }
  deletion_protection_enabled = local.input.dynamodb_deletion_protection_enabled
}
