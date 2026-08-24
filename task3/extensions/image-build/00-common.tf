data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  common_tags = {
    Project     = local.input.project_name
    CandidateId = local.input.candidate_id
    Task        = "3"
    ManagedBy   = "Terraform"
  }

  source_bucket_name = "${local.input.project_name}-build-${local.input.candidate_id}-${data.aws_caller_identity.current.account_id}"
  project_name       = "${local.input.project_name}-image-build"
  dockerfile_key     = "build/Dockerfile.binary"
  build_targets_key  = "build/build-targets.json"

  build_targets = merge(
    {
      user = {
        binary_object_key = local.input.binary_object_keys.user
        repository_url    = local.input.ecr_repository_urls.user
        image_tag         = local.input.image_tag
      }
      product = {
        binary_object_key = local.input.binary_object_keys.product
        repository_url    = local.input.ecr_repository_urls.product
        image_tag         = local.input.image_tag
      }
      stress = {
        binary_object_key = local.input.binary_object_keys.stress
        repository_url    = local.input.ecr_repository_urls.stress
        image_tag         = local.input.image_tag
      }
    },
    {
      for name, workload in local.input.additional_workloads :
      name => {
        binary_object_key = workload.binary_object_key
        repository_url    = local.input.additional_ecr_repository_urls[name]
        image_tag         = workload.image_tag
      }
    },
  )

  repository_names = {
    for name, target in local.build_targets :
    name => element(reverse(split("/", target.repository_url)), 0)
  }
}
