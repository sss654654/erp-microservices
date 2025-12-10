data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/iam/eks-node-role/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "mysql_secret" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/secrets/mysql-secret/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_iam_role_policy" "eks_node_secrets_manager" {
  role = data.terraform_remote_state.iam.outputs.role_name
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
        data.terraform_remote_state.mysql_secret.outputs.secret_arn
      ]
    }]
  })
}

output "policy_id" {
  value = aws_iam_role_policy.eks_node_secrets_manager.id
}
