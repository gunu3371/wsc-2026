terraform {
  required_version = ">= 1.8.0"
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
  region  = "ap-southeast-1"
  profile = var.aws_profile
  default_tags {
    tags = merge(var.tags, { CandidateId = var.candidate_id })
  }
}

