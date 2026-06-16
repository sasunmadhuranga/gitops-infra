variable "project_name"          { type = string }
variable "environment"           { type = string }
variable "ecr_repo_name"         { type = string }
variable "image_retention_count" { type = number }

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}-${var.ecr_repo_name}"
  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.ecr_repo_name}"
  }
}

# Lifecycle policy: keep only the N most recent images to avoid storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "repository_url" { value = aws_ecr_repository.app.repository_url }
output "repository_arn" { value = aws_ecr_repository.app.arn }
