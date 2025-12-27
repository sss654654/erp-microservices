resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-codebuild-role"
    Environment = var.environment
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

resource "aws_iam_role_policy" "codebuild_ecr" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_eks" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-eks-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "arn:aws:eks:ap-northeast-2:*:cluster/${var.project_name}-${var.environment}"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_logs" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-logs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/aws/codebuild/*"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_s3" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::codepipeline-ap-northeast-2-*/*"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_codeconnections" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-codeconnections-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codeconnections:UseConnection",
        "codeconnections:GetConnectionToken",
        "codeconnections:GetConnection"
      ]
      Resource = "arn:aws:codeconnections:ap-northeast-2:*:connection/*"
    }]
  })
}

# Secrets Manager 읽기 권한 (buildspec.yml에서 필요)
resource "aws_iam_role_policy" "codebuild_secrets" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:erp/*"
    }]
  })
}

# Parameter Store 읽기 권한 (buildspec.yml에서 필요)
resource "aws_iam_role_policy" "codebuild_ssm" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ssm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/erp/*"
    }]
  })
}

# ECR 이미지 스캔 권한 (buildspec.yml에서 필요)
resource "aws_iam_role_policy" "codebuild_ecr_scan" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ecr-scan-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:StartImageScan",
        "ecr:DescribeImageScanFindings"
      ]
      Resource = "*"
    }]
  })
}

variable "project_name" {}
variable "environment" {}

output "role_arn" {
  value = aws_iam_role.codebuild.arn
}

output "role_name" {
  value = aws_iam_role.codebuild.name
}
