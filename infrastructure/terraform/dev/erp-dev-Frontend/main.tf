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
    key            = "dev/frontend/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

variable "project_name" {
  default = "erp-dev"
}

variable "environment" {
  default = "dev"
}

module "s3" {
  source       = "./s3"
  project_name = var.project_name
  environment  = var.environment
}

module "cloudfront" {
  source           = "./cloudfront"
  bucket_id        = module.s3.bucket_id
  website_endpoint = module.s3.website_endpoint
  project_name     = var.project_name
  environment      = var.environment
}

output "s3_bucket_name" {
  value = module.s3.bucket_id
}

output "cloudfront_distribution_id" {
  value = module.cloudfront.distribution_id
}

output "cloudfront_url" {
  value = module.cloudfront.distribution_url
}
