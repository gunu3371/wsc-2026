output "bucket" {
  value = aws_s3_bucket.this.id
}
output "table" {
  value = aws_dynamodb_table.this.name
}
output "state_machine_arn" {
  value = aws_sfn_state_machine.this.arn
}

