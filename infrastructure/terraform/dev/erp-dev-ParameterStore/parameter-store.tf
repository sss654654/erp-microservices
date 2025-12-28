terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/parameter-store/terraform.tfstate"
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

# Data sources
data "aws_caller_identity" "current" {}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Parameter Store for buildspec.yml
resource "aws_ssm_parameter" "account_id" {
  name  = "/${var.project_name}/${var.environment}/account-id"
  type  = "String"
  value = data.aws_caller_identity.current.account_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-account-id"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "region" {
  name  = "/${var.project_name}/${var.environment}/region"
  type  = "String"
  value = var.region

  tags = {
    Name        = "${var.project_name}-${var.environment}-region"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/${var.project_name}/${var.environment}/eks/cluster-name"
  type  = "String"
  value = data.terraform_remote_state.eks.outputs.cluster_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-cluster-name"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "ecr_repository_prefix" {
  name  = "/${var.project_name}/${var.environment}/ecr/repository-prefix"
  type  = "String"
  value = var.project_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr-prefix"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "project_name" {
  name  = "/${var.project_name}/${var.environment}/project-name"
  type  = "String"
  value = var.project_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-project-name"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "environment" {
  name  = "/${var.project_name}/${var.environment}/environment"
  type  = "String"
  value = var.environment

  tags = {
    Name        = "${var.project_name}-${var.environment}-environment"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
