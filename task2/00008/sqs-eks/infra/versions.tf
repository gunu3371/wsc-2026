terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.1" }
  }
}
provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Project     = "national-skills-2026"
      CandidateId = "00008"
      ManagedBy   = "Terraform"
    }
  }
}

