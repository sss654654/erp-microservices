data "terraform_remote_state" "databases" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/databases/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/iam/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# MySQL Secret
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
    host     = data.terraform_remote_state.databases.outputs.rds_endpoint
    port     = "3306"
    database = "erp"
  })
}

# IAM Policy: EKS Node Role에 Secret 읽기 권한 추가
resource "aws_iam_role_policy" "eks_node_secrets_manager" {
  role = data.terraform_remote_state.iam.outputs.eks_node_role_name
  name = "eks-node-secrets-manager-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        aws_secretsmanager_secret.mysql.arn
      ]
    }]
  })
}
