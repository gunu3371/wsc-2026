data "archive_file" "consumer" {
  type = "zip"
  source {
    content  = file("${path.module}/../assets/msk/lambda/consumer.py")
    filename = "index.py"
  }
  output_path = "${path.module}/consumer.zip"
}
data "archive_file" "alert_consumer" {
  type = "zip"
  source {
    content  = file("${path.module}/../assets/msk/lambda/alert_consumer.py")
    filename = "index.py"
  }
  output_path = "${path.module}/alert-consumer.zip"
}
resource "aws_lambda_layer_version" "kafka_python" {
  filename            = local.kafka_layer_path
  layer_name          = "wsc2026-msk-kafka-python"
  compatible_runtimes = [local.input.lambda_runtime]
  source_code_hash    = try(filebase64sha256(local.kafka_layer_path), null)

  lifecycle {
    precondition {
      condition     = fileexists(local.kafka_layer_path)
      error_message = "Run ../scripts/build-msk-lambda-layer.ps1 from task2 before planning the MSK module."
    }
  }
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
      Effect = "Allow", Action = ["kafka-cluster:DescribeTopic", "kafka-cluster:ReadData"], Resource = [aws_msk_topic.raw.arn, aws_msk_topic.alert.arn]
      }, {
      Effect = "Allow", Action = "kafka-cluster:WriteData", Resource = aws_msk_topic.alert.arn
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

# VPC Lambda 생성 시 AWS가 execution role의 ENI 권한을 즉시 재확인한다.
# inline policy가 IAM 전체에 전파된 뒤 함수를 생성해 CreateNetworkInterface 오류를 방지한다.
resource "time_sleep" "lambda_iam_propagation" {
  depends_on      = [aws_iam_role_policy.lambda]
  create_duration = "30s"
}

resource "aws_lambda_function" "consumer" {
  # 기존 구현(비활성): role 참조만으로 생성 순서를 결정
  depends_on = [time_sleep.lambda_iam_propagation]

  function_name    = "wsc2026-sensor-consumer"
  role             = aws_iam_role.lambda.arn
  runtime          = local.input.lambda_runtime
  handler          = "index.handler"
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  timeout          = 60
  layers           = [aws_lambda_layer_version.kafka_python.arn]
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.clients.id]
  }
  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.data.name, ALERT_TOPIC = aws_msk_topic.alert.name, BOOTSTRAP_SERVER = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
    }
  }
}
resource "aws_lambda_function" "alert" {
  # 기존 구현(비활성): role 참조만으로 생성 순서를 결정
  depends_on = [time_sleep.lambda_iam_propagation]

  function_name    = "wsc2026-sensor-alert-consumer"
  role             = aws_iam_role.lambda.arn
  runtime          = local.input.lambda_runtime
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
  topics            = [aws_msk_topic.raw.name]
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
}
resource "aws_lambda_event_source_mapping" "alert" {
  event_source_arn  = aws_msk_cluster.this.arn
  function_name     = aws_lambda_function.alert.arn
  topics            = [aws_msk_topic.alert.name]
  starting_position = "LATEST"
  batch_size        = 100
  enabled           = true
}
