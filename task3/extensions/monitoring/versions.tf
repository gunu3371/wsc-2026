terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = local.input.aws_region
  default_tags {
    tags = {
      Project     = local.input.project_name
      CandidateId = local.input.candidate_id
      Task        = "3"
      ManagedBy   = "Terraform"
    }
  }
}
