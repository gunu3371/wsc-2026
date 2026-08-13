resource "aws_kinesis_stream" "orders" {
  name = "wsc2026-order-stream"
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"
}

