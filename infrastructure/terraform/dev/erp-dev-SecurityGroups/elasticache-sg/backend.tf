terraform {
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/security-groups/elasticache-sg/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}
