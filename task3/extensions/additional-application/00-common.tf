locals {
  namespace      = "apdev"
  alb_group_name = substr("${local.input.project_name}-${local.input.candidate_id}-api", 0, 63)

  common_tags = {
    Project     = local.input.project_name
    CandidateId = local.input.candidate_id
    Task        = "3"
    ManagedBy   = "Terraform"
  }

  workload_orders = {
    for index, name in sort(keys(local.input.additional_workloads)) :
    name => 100 + index
  }
}
