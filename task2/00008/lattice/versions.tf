terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Project   = "national-skills-2026"
      TaskId    = "00008"
      ManagedBy = "Terraform"
    }
  }
}

