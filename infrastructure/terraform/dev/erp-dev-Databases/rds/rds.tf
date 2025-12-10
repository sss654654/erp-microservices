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
    key    = "dev/security-groups/rds-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = data.terraform_remote_state.vpc.outputs.data_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "mysql" {
  identifier              = "${var.project_name}-${var.environment}-mysql"
  engine                  = "mysql"
  engine_version          = var.mysql_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.mysql_database_name
  username                = var.mysql_username
  password                = var.mysql_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [data.terraform_remote_state.security_groups.outputs.sg_id]
  skip_final_snapshot     = true
  backup_retention_period = 1
  multi_az                = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql"
    Environment = var.environment
  }
}
