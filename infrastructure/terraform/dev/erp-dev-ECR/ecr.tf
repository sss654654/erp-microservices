terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/ecr/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ECR Repository for Lambda
resource "aws_ecr_repository" "employee_lambda" {
  name                 = "${var.project_name}/employee-service-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-employee-service-lambda"
    Environment = var.environment
    Service     = "employee"
    Type        = "lambda"
  }
}

# ECR Repositories for EKS Services
resource "aws_ecr_repository" "eks_services" {
  for_each = toset(["approval-request-service", "approval-processing-service", "notification-service"])
  
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${each.key}"
    Environment = var.environment
    Service     = each.key
    Type        = "eks"
  }
}
