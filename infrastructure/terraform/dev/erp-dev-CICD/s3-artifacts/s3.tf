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

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "codepipeline-${var.region}-806332783810"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-codepipeline-artifacts"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

variable "project_name" {}
variable "environment" {}
variable "region" {}

output "bucket_name" {
  value = aws_s3_bucket.codepipeline_artifacts.bucket
}
