terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source = "hashicorp/aws", version = "~> 6.0"
    }
    archive = {
      source = "hashicorp/archive", version = "~> 2.4"
    }
  }
}
provider "aws" {
  region  = "ap-northeast-2"
  profile = var.aws_profile
  default_tags {
    tags = merge({
      Project     = "wskorea26-concert"
      CandidateId = var.candidate_id
      ManagedBy   = "Terraform"
    }, var.tags)
  }
}
