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
    key    = "dev/security-groups/elasticache-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-cache-subnet-group"
  subnet_ids = data.terraform_remote_state.vpc.outputs.data_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-cache-subnet-group"
    Environment = var.environment
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  engine_version       = var.redis_version
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [data.terraform_remote_state.security_groups.outputs.sg_id]

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis"
    Environment = var.environment
  }
}
