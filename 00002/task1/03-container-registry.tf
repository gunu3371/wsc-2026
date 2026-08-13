resource "aws_ecr_repository" "book" {
  name = "wskorea26-book-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
  force_delete = true
}

