terraform {
  backend "s3" {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/secrets/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
