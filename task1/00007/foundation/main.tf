terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = "ap-northeast-2"
}
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
data "aws_caller_identity" "current" {

}
locals {
  azs    = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  suffix = ["a", "b", "c"]
}
resource "aws_vpc" "main" {
  cidr_block           = "10.97.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "unicorn-vpc"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "unicorn-igw"
  }
}
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.azs[count.index]
  cidr_block              = "10.97.${count.index}.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "unicorn-subnet-pub-${local.suffix[count.index]}", "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = "10.97.${10 + count.index}.0/24"
  tags = {
    Name = "unicorn-subnet-priv-${local.suffix[count.index]}", "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_eip" "nat" {
  count      = 3
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}
resource "aws_nat_gateway" "main" {
  count         = 3
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
  tags = {
    Name = "unicorn-nat-${local.suffix[count.index]}"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "unicorn-rt-pub"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "unicorn-rt-priv-${local.suffix[count.index]}"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
}
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
resource "aws_security_group" "endpoint" {
  name   = "unicorn-vpce-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ecr.api", "ecr.dkr", "logs", "sts", "eks", "ec2", "monitoring"])
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoint.id]
}
resource "aws_vpc_endpoint" "gateway" {
  for_each          = toset(["s3", "dynamodb"])
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-2.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
}
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/unicorn/vpc/flow"
  retention_in_days = 30
}
resource "aws_iam_role" "flow" {
  name = "unicorn-vpc-flow-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}
resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flow.arn
}
resource "aws_kms_key" "app" {
  description             = "Unicorn application key"
  enable_key_rotation     = true
  rotation_period_in_days = 90
}
resource "aws_kms_alias" "app" {
  name          = "alias/unicorn-kms-app"
  target_key_id = aws_kms_key.app.key_id
}
resource "aws_kms_key" "data" {
  description             = "Unicorn data key"
  enable_key_rotation     = true
  rotation_period_in_days = 90
}
resource "aws_kms_alias" "data" {
  name          = "alias/unicorn-kms-data"
  target_key_id = aws_kms_key.data.key_id
}
resource "aws_kms_key" "platform" {
  description             = "Unicorn platform key"
  enable_key_rotation     = true
  rotation_period_in_days = 90
  multi_region            = true
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Sid = "AccountAdministration", Effect = "Allow", Principal = {
        AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }, Action = "kms:*", Resource = "*"
      }, {
      Sid = "CloudWatchLogs", Effect = "Allow", Principal = {
        Service = "logs.ap-northeast-2.amazonaws.com"
        }, Action = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"], Resource = "*", Condition = {
        ArnLike = {
          "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:log-group:/unicorn/*"
        }
      }
    }]
  })

}
resource "aws_kms_alias" "platform" {
  name          = "alias/unicorn-kms-platform"
  target_key_id = aws_kms_key.platform.key_id
}
resource "aws_kms_replica_key" "platform_use1" {

  provider        = aws.use1
  primary_key_arn = aws_kms_key.platform.arn
  description     = "Unicorn platform key replica"
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        AWS     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }, Action = "kms:*", Resource = "*"
      }, {
      Effect = "Allow", Principal = {
        Service = "logs.us-east-1.amazonaws.com"
        }, Action = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"], Resource = "*", Condition = {
        ArnLike = {
          "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-unicorn*"
        }
      }
    }]
  })

}
resource "aws_kms_alias" "platform_use1" {
  provider      = aws.use1
  name          = "alias/unicorn-kms-platform"
  target_key_id = aws_kms_replica_key.platform_use1.key_id
}
resource "aws_s3_bucket" "web" {
  bucket = "unicorn-web-${data.aws_caller_identity.current.account_id}"
}
resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "web" {
  bucket = aws_s3_bucket.web.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_object" "index" {
  bucket                 = aws_s3_bucket.web.id
  key                    = "index.html"
  source                 = "${path.module}/../assets/index.html"
  content_type           = "text/html"
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data.arn
  etag                   = filemd5("${path.module}/../assets/index.html")
}
resource "aws_dynamodb_table" "concert" {
  name                        = "unicorn-concert-db"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "booking_id"
  deletion_protection_enabled = true
  attribute {
    name = "booking_id"
    type = "S"
  }
  attribute {
    name = "client_id"
    type = "S"
  }
  attribute {
    name = "created_at"
    type = "S"
  }
  global_secondary_index {
    name            = "client-id-created-at-index"
    hash_key        = "client_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }
}
resource "aws_ecr_repository" "app" {
  name                 = "unicorn-concert-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.data.arn
  }
}
resource "aws_cloudwatch_log_group" "app" {
  name              = "/unicorn/eks/book-app"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.platform.arn
}
output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "app_kms_arn" {
  value = aws_kms_key.app.arn
}
output "data_kms_arn" {
  value = aws_kms_key.data.arn
}
output "platform_kms_arn" {
  value = aws_kms_key.platform.arn
}
output "platform_use1_kms_arn" {
  value = aws_kms_replica_key.platform_use1.arn
}
output "bucket_name" {
  value = aws_s3_bucket.web.id
}
output "table_arn" {
  value = aws_dynamodb_table.concert.arn
}
output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
