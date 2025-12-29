terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_codebuild_project" "unified_build" {
  name          = "${var.project_name}-unified-build"
  description   = "Unified build for all ERP microservices with monitoring"
  service_role  = var.codebuild_role_arn
  
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    type                        = "LINUX_CONTAINER"
    image                       = "aws/codebuild/standard:7.0"
    compute_type                = "BUILD_GENERAL1_SMALL"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }
  
  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_repo}.git"
    buildspec       = "buildspec.yml"
    git_clone_depth = 1
  }
  
  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/${var.project_name}-unified-build"
      stream_name = "build-log"
    }
  }
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-unified-build"
    Environment = var.environment
  }
}

variable "project_name" {}
variable "environment" {}
variable "codebuild_role_arn" {}
variable "github_repo" {}

output "project_name" {
  value = aws_codebuild_project.unified_build.name
}

output "project_arn" {
  value = aws_codebuild_project.unified_build.arn
}
