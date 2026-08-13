terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    awscc = {
      source = "hashicorp/awscc", version = "~> 1.0"
    }
  }
}
provider "aws" {
  region  = "ap-northeast-2"
  profile = var.aws_profile
  default_tags {
    tags = var.tags
  }
}

provider "awscc" {
  region  = "ap-northeast-2"
  profile = var.aws_profile
}

