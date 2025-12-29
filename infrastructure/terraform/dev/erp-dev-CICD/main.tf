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
    key            = "dev/cicd/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/iam/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

variable "project_name" {
  default = "erp"
}

variable "environment" {
  default = "dev"
}

variable "region" {
  default = "ap-northeast-2"
}

variable "github_repo" {
  default = "sss654654/erp-microservices"
}

variable "github_branch" {
  default = "main"
}

module "s3_artifacts" {
  source       = "./s3-artifacts"
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
}

module "codebuild" {
  source             = "./codebuild"
  project_name       = var.project_name
  environment        = var.environment
  codebuild_role_arn = data.terraform_remote_state.iam.outputs.codebuild_role_arn
  github_repo        = var.github_repo
}

module "codepipeline" {
  source                 = "./codepipeline"
  project_name           = var.project_name
  environment            = var.environment
  region                 = var.region
  codepipeline_role_arn  = data.terraform_remote_state.iam.outputs.codepipeline_role_arn
  codepipeline_role_name = data.terraform_remote_state.iam.outputs.codepipeline_role_name
  codebuild_project_name = module.codebuild.project_name
  codebuild_project_arn  = module.codebuild.project_arn
  s3_bucket_name         = module.s3_artifacts.bucket_name
  github_repo            = var.github_repo
  github_branch          = var.github_branch
}

output "s3_bucket_name" {
  value = module.s3_artifacts.bucket_name
}

output "codebuild_project_name" {
  value = module.codebuild.project_name
}

output "codebuild_project_arn" {
  value = module.codebuild.project_arn
}

output "codepipeline_name" {
  value = module.codepipeline.pipeline_name
}

output "codepipeline_arn" {
  value = module.codepipeline.pipeline_arn
}
