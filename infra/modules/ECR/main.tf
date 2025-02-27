resource "aws_ecr_repository" "app_repo" {
  name = var.repo_name
}
