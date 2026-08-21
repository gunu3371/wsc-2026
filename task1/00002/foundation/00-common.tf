data "aws_caller_identity" "current" {}
locals {
  azs    = local.input.availability_zones
  bucket = "wskorea26-concert-bucket-${local.input.candidate_id}"
}
