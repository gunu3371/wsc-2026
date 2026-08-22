terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = local.input.region
  profile = local.input.aws_profile

  default_tags {
    tags = merge(local.input.tags, {
      Project   = "wsc2026"
      TaskId    = local.input.task_id
      ManagedBy = "Terraform"
    })
  }
}

provider "aws" {
  alias   = "global"
  region  = "us-east-1"
  profile = local.input.aws_profile

  default_tags {
    tags = merge(local.input.tags, {
      Project   = "wsc2026"
      TaskId    = local.input.task_id
      ManagedBy = "Terraform"
    })
  }
}
