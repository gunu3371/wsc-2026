resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/wsc2026-msk-cluster"
  retention_in_days = 14
}
resource "aws_msk_cluster" "this" {
  cluster_name           = "wsc2026-msk-cluster"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 2
  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = aws_subnet.private[*].id
    security_groups = [aws_security_group.msk.id]
    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }
  client_authentication {
    sasl {
      iam   = true
      scram = false
    }
    unauthenticated = false
  }
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }
}

