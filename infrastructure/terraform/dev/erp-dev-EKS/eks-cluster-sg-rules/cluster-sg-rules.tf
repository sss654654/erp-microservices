terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_eks_cluster" "main" {
  name = "${var.project_name}-${var.environment}"
}

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${var.environment}-vpc"]
  }
}

resource "aws_security_group_rule" "eks_cluster_vpc_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.main.cidr_block]
  security_group_id = data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description       = "Allow all traffic from VPC for NLB"
}
