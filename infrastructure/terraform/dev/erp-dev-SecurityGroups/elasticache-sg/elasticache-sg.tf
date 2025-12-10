data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "eks_sg" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/security-groups/eks-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_security_group" "elasticache" {
  name        = "${var.project_name}-${var.environment}-elasticache-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.eks_sg.outputs.sg_id]
    description     = "Redis from EKS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-elasticache-sg"
    Environment = var.environment
  }
}
