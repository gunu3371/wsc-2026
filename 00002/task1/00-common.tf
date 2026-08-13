data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
  bucket = "wskorea26-concert-bucket-${var.candidate_id}"
}

