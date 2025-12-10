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
    key            = "dev/eks/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/subnet/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "security_groups" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/security-groups/eks-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
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

module "eks_cluster" {
  source                = "./eks-cluster"
  project_name          = var.project_name
  environment           = var.environment
  kubernetes_version    = "1.31"
  private_subnet_ids    = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  eks_sg_id             = data.terraform_remote_state.security_groups.outputs.sg_id
  eks_cluster_role_arn  = data.terraform_remote_state.iam.outputs.eks_cluster_role_arn
}

module "eks_node_group" {
  source              = "./eks-node-group"
  project_name        = var.project_name
  environment         = var.environment
  cluster_name        = module.eks_cluster.cluster_name
  private_subnet_ids  = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  eks_node_role_arn   = data.terraform_remote_state.iam.outputs.eks_node_role_arn
  node_instance_types = ["t3.small"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3
}

module "eks_cluster_sg_rules" {
  source       = "./eks-cluster-sg-rules"
  project_name = var.project_name
  environment  = var.environment
}

output "cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks_cluster.cluster_security_group_id
}

output "cluster_arn" {
  value = module.eks_cluster.cluster_arn
}
