terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/iam/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

variable "project_name" {
  default = "erp"
}

variable "environment" {
  default = "dev"
}

module "eks_cluster_role" {
  source       = "./eks-cluster-role"
  project_name = var.project_name
  environment  = var.environment
}

module "eks_node_role" {
  source       = "./eks-node-role"
  project_name = var.project_name
  environment  = var.environment
}

module "codebuild_role" {
  source       = "./codebuild-role"
  project_name = var.project_name
  environment  = var.environment
}

module "codepipeline_role" {
  source       = "./codepipeline-role"
  project_name = var.project_name
  environment  = var.environment
}

output "eks_cluster_role_arn" {
  value = module.eks_cluster_role.role_arn
}

output "eks_cluster_role_name" {
  value = module.eks_cluster_role.role_name
}

output "eks_node_role_arn" {
  value = module.eks_node_role.role_arn
}

output "eks_node_role_name" {
  value = module.eks_node_role.role_name
}

output "codebuild_role_arn" {
  value = module.codebuild_role.role_arn
}

output "codebuild_role_name" {
  value = module.codebuild_role.role_name
}

output "codepipeline_role_arn" {
  value = module.codepipeline_role.role_arn
}

output "codepipeline_role_name" {
  value = module.codepipeline_role.role_name
}
