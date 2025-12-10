resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-${var.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-codepipeline-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "codepipeline_s3" {
  role = aws_iam_role.codepipeline.id
  name = "codepipeline-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::codepipeline-ap-northeast-2-*",
        "arn:aws:s3:::codepipeline-ap-northeast-2-*/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_codebuild" {
  role = aws_iam_role.codepipeline.id
  name = "codepipeline-codebuild-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ]
      Resource = "arn:aws:codebuild:ap-northeast-2:*:project/${var.project_name}-${var.environment}-*"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_codeconnections" {
  role = aws_iam_role.codepipeline.id
  name = "codepipeline-codeconnections-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codeconnections:UseConnection",
        "codeconnections:GetConnectionToken",
        "codeconnections:GetConnection",
        "codestar-connections:UseConnection"
      ]
      Resource = [
        "arn:aws:codeconnections:ap-northeast-2:*:connection/*",
        "arn:aws:codestar-connections:ap-northeast-2:*:connection/*"
      ]
    }]
  })
}

variable "project_name" {}
variable "environment" {}

output "role_arn" {
  value = aws_iam_role.codepipeline.arn
}

output "role_name" {
  value = aws_iam_role.codepipeline.name
}
