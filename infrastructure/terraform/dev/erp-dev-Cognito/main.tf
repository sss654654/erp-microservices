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
    key            = "dev/cognito/terraform.tfstate"
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

module "user_pool" {
  source       = "./user-pool"
  project_name = var.project_name
  environment  = var.environment
}

output "user_pool_id" {
  value = module.user_pool.user_pool_id
}

output "user_pool_arn" {
  value = module.user_pool.user_pool_arn
}

output "user_pool_client_id" {
  value = module.user_pool.user_pool_client_id
}

output "user_pool_domain" {
  value = module.user_pool.user_pool_domain
}
