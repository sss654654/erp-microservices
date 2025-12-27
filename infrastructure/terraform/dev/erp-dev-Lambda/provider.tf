terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/lambda/terraform.tfstate"
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
  region = "ap-northeast-2"
}
