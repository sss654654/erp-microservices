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

data "aws_codestarconnections_connection" "github" {
  arn = "arn:aws:codeconnections:${var.region}:806332783810:connection/a0f29740-bbcd-419a-84e9-7412a5dded5e"
}

resource "aws_iam_role_policy" "codepipeline_codebuild" {
  name = "CodeBuildAccess"
  role = var.codepipeline_role_name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = var.codebuild_project_arn
      }
    ]
  })
}

resource "aws_codepipeline" "unified_pipeline" {
  name     = "${var.project_name}-unified-pipeline"
  role_arn = var.codepipeline_role_arn
  
  artifact_store {
    type     = "S3"
    location = var.s3_bucket_name
  }
  
  stage {
    name = "Source"
    
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      
      configuration = {
        ConnectionArn        = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repo
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }
  
  stage {
    name = "Build"
    
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      
      configuration = {
        ProjectName = var.codebuild_project_name
      }
    }
  }
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-unified-pipeline"
    Environment = var.environment
  }
  
  depends_on = [aws_iam_role_policy.codepipeline_codebuild]
}

variable "project_name" {}
variable "environment" {}
variable "region" {}
variable "codepipeline_role_arn" {}
variable "codepipeline_role_name" {}
variable "codebuild_project_name" {}
variable "codebuild_project_arn" {}
variable "s3_bucket_name" {}
variable "github_repo" {}
variable "github_branch" {}

output "pipeline_name" {
  value = aws_codepipeline.unified_pipeline.name
}

output "pipeline_arn" {
  value = aws_codepipeline.unified_pipeline.arn
}
