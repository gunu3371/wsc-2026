locals {
  common_tags = {
    Project     = local.input.project_name
    CandidateId = local.input.candidate_id
    Task        = "3"
    ManagedBy   = "Terraform"
  }
}
