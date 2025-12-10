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
    key            = "dev/secrets/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/databases/rds/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

variable "project_name" {
  default = "erp"
}

variable "environment" {
  default = "dev"
}

variable "mysql_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

module "mysql_secret" {
  source          = "./mysql-secret"
  project_name    = var.project_name
  environment     = var.environment
  mysql_password  = var.mysql_password
  rds_endpoint    = data.terraform_remote_state.rds.outputs.endpoint
}

output "secret_arn" {
  value = module.mysql_secret.secret_arn
}

output "secret_name" {
  value = module.mysql_secret.secret_name
}
