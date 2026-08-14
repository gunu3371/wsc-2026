data "aws_caller_identity" "current" {}
locals {
  azs    = var.availability_zones
  bucket = "wskorea26-concert-bucket-${var.candidate_id}"
}
