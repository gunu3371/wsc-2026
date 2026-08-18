data "archive_file" "consumer" {
  type = "zip"
  source {
    content  = file("${path.module}/lambda/consumer.py")
    filename = "index.py"
  }
  output_path = "${path.module}/consumer.zip"
}
data "archive_file" "alert_consumer" {
  type = "zip"
  source {
    content  = file("${path.module}/lambda/alert_consumer.py")
    filename = "index.py"
  }
  output_path = "${path.module}/alert-consumer.zip"
}
resource "aws_iam_role" "lambda" {
  name = "wsc2026-msk-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "lambda.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["kafka:DescribeCluster", "kafka:DescribeClusterV2", "kafka:GetBootstrapBrokers"], Resource = aws_msk_cluster.this.arn
      }, {
      Effect = "Allow", Action = ["kafka-cluster:Connect", "kafka-cluster:DescribeGroup", "kafka-cluster:AlterGroup"], Resource = [aws_msk_cluster.this.arn, "arn:aws:kafka:ap-northeast-1:${data.aws_caller_identity.current.account_id}:group/wsc2026-msk-cluster/*/*"]
      }, {
      Effect = "Allow", Action = ["kafka-cluster:DescribeTopic", "kafka-cluster:ReadData"], Resource = "arn:aws:kafka:ap-northeast-1:${data.aws_caller_identity.current.account_id}:topic/wsc2026-msk-cluster/*/*"
      }, {
      Effect = "Allow", Action = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeVpcs", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DeleteNetworkInterface"], Resource = "*"
      }, {
      Effect = "Allow", Action = "dynamodb:PutItem", Resource = aws_dynamodb_table.data.arn
      }, {
      Effect = "Allow", Action = "s3:PutObject", Resource = "${aws_s3_bucket.alert.arn}/alert/*"
      }, {
      Effect = "Allow", Action = "sns:Publish", Resource = aws_sns_topic.alert.arn
      }, {
      Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*"
    }]
  })
}
resource "aws_lambda_function" "consumer" {
  function_name    = "wsc2026-sensor-consumer"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "index.handler"
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  timeout          = 60
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.clients.id]
  }
  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.data.name, ALERT_TOPIC = "wsc2026-sensor-alert", BOOTSTRAP_SERVER = aws_msk_cluster.this.bootstrap_brokers_sasl_iam, SNS_TOPIC_ARN = aws_sns_topic.alert.arn, S3_BUCKET = aws_s3_bucket.alert.id
    }
  }
}
resource "aws_lambda_function" "alert" {
  function_name    = "wsc2026-sensor-alert-consumer"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "index.handler"
  filename         = data.archive_file.alert_consumer.output_path
  source_code_hash = data.archive_file.alert_consumer.output_base64sha256
  timeout          = 60
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.clients.id]
  }
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alert.arn, S3_BUCKET = aws_s3_bucket.alert.id
    }
  }
}
resource "aws_lambda_event_source_mapping" "raw" {
  event_source_arn  = aws_msk_cluster.this.arn
  function_name     = aws_lambda_function.consumer.arn
  topics            = ["wsc2026-sensor-raw"]
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
}
resource "aws_lambda_event_source_mapping" "alert" {
  event_source_arn  = aws_msk_cluster.this.arn
  function_name     = aws_lambda_function.alert.arn
  topics            = ["wsc2026-sensor-alert"]
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
}
