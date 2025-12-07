# ============================================================
# Security Module - 2단계 실행 필요
# ============================================================
# 
# 1차 실행 (EKS 생성 전):
#   terraform apply -target=aws_security_group.alb \
#                   -target=aws_security_group.eks \
#                   -target=aws_security_group.rds \
#                   -target=aws_security_group.elasticache \
#                   -target=aws_iam_role.eks_cluster \
#                   -target=aws_iam_role.eks_node \
#                   -target=aws_iam_role_policy_attachment.eks_cluster_policy \
#                   -target=aws_iam_role_policy_attachment.eks_worker_node_policy \
#                   -target=aws_iam_role_policy_attachment.eks_cni_policy \
#                   -target=aws_iam_role_policy_attachment.eks_container_registry_policy
#
#   → -target 옵션으로 지정한 리소스만 생성
#   → 3개 EKS Cluster SG 규칙은 자동으로 제외됨 (EKS outputs 없음)
#
# 2차 실행 (EKS 생성 후):
#   terraform apply
#
#   → -target 없이 전체 실행
#   → 3개 EKS Cluster SG 규칙이 추가됨
#
# ============================================================

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# EKS Security Group
resource "aws_security_group" "eks" {
  name        = "${var.project_name}-${var.environment}-eks-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 8081
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Application ports from ALB"
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
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

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
    description     = "MySQL from EKS (Terraform created SG)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
  }
}

# ============================================================
# 아래 3개 규칙은 1차 실행 시 -target 옵션으로 제외됨
# 2차 실행 시 terraform apply로 추가됨
# ============================================================

# RDS Security Group Rule - Allow from EKS Cluster SG (auto-created by EKS)
resource "aws_security_group_rule" "rds_from_eks_cluster" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  description              = "MySQL from EKS Cluster SG (auto-created)"
}

# EKS Cluster Security Group Rule - Allow from ALB
resource "aws_security_group_rule" "eks_cluster_from_alb" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8084
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  source_security_group_id = aws_security_group.alb.id
  description              = "Application ports from ALB"
}

# ElastiCache Security Group Rule - Allow from EKS Cluster SG
resource "aws_security_group_rule" "elasticache_from_eks_cluster" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticache.id
  source_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  description              = "Redis from EKS Cluster SG (auto-created)"
}

# ElastiCache Security Group
resource "aws_security_group" "elasticache" {
  name        = "${var.project_name}-${var.environment}-elasticache-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
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

