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
    key            = "dev/api-gateway/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# Remote state
data "terraform_remote_state" "alb_sg" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/security-groups/alb-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/alb/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "vpc_subnet" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/subnet/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

variable "project_name" {
  default = "erp"
}

variable "environment" {
  default = "dev"
}

# NLB Module
module "nlb" {
  source = "./nlb"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids  = data.terraform_remote_state.vpc_subnet.outputs.private_subnet_ids
}

# API Gateway Module
module "api_gateway" {
  source = "./api-gateway"

  project_name        = var.project_name
  environment         = var.environment
  private_subnet_ids  = data.terraform_remote_state.vpc_subnet.outputs.private_subnet_ids
  security_group_ids  = [data.terraform_remote_state.alb_sg.outputs.sg_id]
  
  nlb_listener_arns = module.nlb.listener_arns
}

output "api_endpoint" {
  value = module.api_gateway.api_endpoint
}

output "api_id" {
  value = module.api_gateway.api_id
}

output "nlb_dns_name" {
  value = module.nlb.nlb_dns_name
}

output "target_group_arns" {
  value = module.nlb.target_group_arns
}
