resource "aws_iam_role" "config" {
  name = "wsc2026-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "config.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}
resource "aws_iam_role_policy" "config_bucket" {
  role = aws_iam_role.config.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["s3:GetBucketAcl", "s3:ListBucket"], Resource = aws_s3_bucket.audit.arn
      }, {
      Effect = "Allow", Action = "s3:PutObject", Resource = "${aws_s3_bucket.audit.arn}/config/*"
    }]
  })
}
resource "aws_config_configuration_recorder" "this" {
  name     = "wsc2026-config-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}
resource "aws_config_delivery_channel" "this" {
  name           = "wsc2026-config-delivery"
  s3_bucket_name = aws_s3_bucket.audit.id
  s3_key_prefix  = "config"
  depends_on     = [aws_s3_bucket_policy.audit]
}
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}
resource "aws_config_config_rule" "ssh" {
  name = "wsc2026-sg-ssh-rule"
  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }
  depends_on = [aws_config_configuration_recorder.this]
}
resource "aws_config_config_rule" "tags" {
  name = "wsc2026-required-tags-rule"
  input_parameters = jsonencode({
    tag1Key = "Name"
  })
  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }
  scope {
    compliance_resource_types = ["AWS::EC2::Instance"]
  }
  depends_on = [aws_config_configuration_recorder.this]
}
