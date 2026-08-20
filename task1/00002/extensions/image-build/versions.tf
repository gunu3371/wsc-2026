terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = local.input.aws_profile

  default_tags {
    tags = merge(local.input.tags, {
      TaskId = local.input.task_id
    })
  }
}
