terraform {
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/vpc/subnet/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
}
