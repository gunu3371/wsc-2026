data "aws_caller_identity" "current" {}
locals {
  az      = ["a", "d"]
  public  = ["192.168.0.0/24", "192.168.1.0/24"]
  private = ["192.168.10.0/24", "192.168.11.0/24"]
  bucket  = "wsc2026-sensor-alert-bucket-${var.candidate_id}"
}
