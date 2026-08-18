terraform {

  required_version = ">= 1.6.0"
  required_providers {

    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    archive = {
      source = "hashicorp/archive", version = "~> 2.7"
    }

  }

}

provider "aws" {
  region = "ap-southeast-1"
}
data "aws_caller_identity" "current" {

}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_ami" "al2023" {

  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

resource "aws_dynamodb_table" "reservation" {

  name             = "bigbae-nosql-reservation-table"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "train_id"
  range_key        = "seat_id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  attribute {
    name = "train_id"
    type = "S"
  }
  attribute {
    name = "seat_id"
    type = "S"
  }
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "reserved_at"
    type = "S"
  }
  global_secondary_index {

    name            = "gsi-user-reservations"
    hash_key        = "user_id"
    range_key       = "reserved_at"
    projection_type = "ALL"

  }
  point_in_time_recovery {
    enabled = true
  }

}

resource "aws_dynamodb_table" "audit" {

  name         = "bigbae-nosql-audit-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  attribute {
    name = "event_id"
    type = "S"
  }
  point_in_time_recovery {
    enabled = true
  }

}

data "archive_file" "audit" {
  type        = "zip"
  source_file = "${path.module}/../assets/nosql/lambda.py"
  output_path = "${path.module}/audit.zip"
}
resource "aws_iam_role" "lambda" {

  name = "bigbae-nosql-audit-role"
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
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"], Resource = "${aws_dynamodb_table.reservation.arn}/stream/*"
      },
      {
        Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.audit.arn
      },
      {
        Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:ap-southeast-1:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

}
resource "aws_lambda_function" "audit" {

  function_name    = "bigbae-nosql-reservation-audit"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.audit.output_path
  source_code_hash = data.archive_file.audit.output_base64sha256
  handler          = "lambda.handler"
  runtime          = "python3.13"
  timeout          = 30
  environment {
    variables = {
      AUDIT_TABLE_NAME = aws_dynamodb_table.audit.name
    }
  }

}
resource "aws_lambda_event_source_mapping" "audit" {

  event_source_arn  = aws_dynamodb_table.reservation.stream_arn
  function_name     = aws_lambda_function.audit.arn
  starting_position = "LATEST"
  batch_size        = 10

}

resource "aws_vpc" "app" {
  cidr_block           = "10.71.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "bigbae-nosql-vpc"
  }
}
resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = "10.71.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_security_group" "app" {

  name   = "bigbae-nosql-app-sg"
  vpc_id = aws_vpc.app.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_iam_role" "ec2" {

  name = "bigbae-nosql-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })

}
resource "aws_iam_role_policy" "ec2" {

  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"], Resource = [aws_dynamodb_table.reservation.arn, "${aws_dynamodb_table.reservation.arn}/index/*"]
    }]
  })

}
resource "aws_iam_instance_profile" "app" {
  name = "bigbae-nosql-app-profile"
  role = aws_iam_role.ec2.name
}
resource "aws_instance" "app" {

  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  user_data = templatefile("${path.module}/../assets/nosql/user-data.sh", {
    app_b64 = base64encode(file("${path.module}/../assets/nosql/app.py"))
  })
  tags = {
    Name = "bigbae-nosql-app-ec2"
  }

}
output "app_public_ip" {
  value = aws_instance.app.public_ip
}
