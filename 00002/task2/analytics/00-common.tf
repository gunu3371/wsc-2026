data "aws_caller_identity" "current" {}

locals {
  az      = ["a", "b"]
  public  = ["10.20.0.0/24", "10.20.1.0/24"]
  private = ["10.20.100.0/24", "10.20.101.0/24"]
}
