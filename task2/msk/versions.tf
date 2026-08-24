terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = ">= 6.60.0, < 7.0.0"
    }
    archive = {
      source = "hashicorp/archive", version = "~> 2.7"
    }
    time = {
      source = "hashicorp/time", version = "~> 0.13"
    }
  }
}
provider "aws" {
  region  = "ap-northeast-1"
  profile = local.input.aws_profile
  default_tags {
    tags = merge(local.input.tags, { TaskId = local.input.task_id })
  }
}

