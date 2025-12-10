data "terraform_remote_state" "databases" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/databases/rds/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

variable "project_name" {}
variable "environment" {}
variable "mysql_username" {
  default = "admin"
}
variable "mysql_password" {
  sensitive = true
}
variable "rds_endpoint" {}

resource "aws_secretsmanager_secret" "mysql" {
  name        = "${var.project_name}/${var.environment}/mysql"
  description = "RDS MySQL credentials for ERP"

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    username = var.mysql_username
    password = var.mysql_password
    host     = var.rds_endpoint
    port     = "3306"
    database = "erp"
  })
}

output "secret_arn" {
  value = aws_secretsmanager_secret.mysql.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.mysql.name
}
