data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "alb_sg" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/security-groups/alb-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_security_group" "eks" {
  name        = "${var.project_name}-${var.environment}-eks-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 8081
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.alb_sg.outputs.sg_id]
    description     = "Application ports from ALB"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within EKS cluster"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-sg"
    Environment = var.environment
  }
}

# ⚠️ 임시 주석: EKS 클러스터 생성 후 활성화
# data "aws_eks_cluster" "main" {
#   name = "erp-dev"
# }

# resource "aws_security_group_rule" "eks_cluster_vpc_ingress" {
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = [data.terraform_remote_state.vpc.outputs.vpc_cidr]
#   security_group_id = data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
#   description       = "Allow all traffic from VPC for NLB"
# }
