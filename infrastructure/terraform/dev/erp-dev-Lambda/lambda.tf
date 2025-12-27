data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/vpc/vpc/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "vpc_subnet" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/vpc/subnet/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "security_groups" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/security-groups/eks-sg/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/databases/rds/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/api-gateway/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/ecr/terraform.tfstate"
    region = var.region
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets" {
  role = aws_iam_role.lambda.id
  name = "lambda-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
    }]
  })
}

resource "aws_lambda_function" "employee" {
  function_name = "${var.project_name}-${var.environment}-employee-service"
  role          = aws_iam_role.lambda.arn
  
  package_type = "Image"
  image_uri    = "${data.terraform_remote_state.ecr.outputs.employee_lambda_repository_url}:latest"
  
  vpc_config {
    subnet_ids         = data.terraform_remote_state.vpc_subnet.outputs.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      SPRING_DATASOURCE_URL = "jdbc:mysql://${data.terraform_remote_state.rds.outputs.endpoint}/${var.project_name}?useSSL=true"
    }
  }
  
  memory_size = 1024
  timeout     = 60
  
  tags = {
    Name = "${var.project_name}-${var.environment}-employee-service"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.employee.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${data.terraform_remote_state.api_gateway.outputs.api_id}/*/*"
}

resource "aws_apigatewayv2_integration" "employee_lambda" {
  api_id             = data.terraform_remote_state.api_gateway.outputs.api_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.employee.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "employee_proxy" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_id
  route_key = "ANY /api/employees/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.employee_lambda.id}"
}

resource "aws_apigatewayv2_route" "employee_root" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_id
  route_key = "ANY /api/employees"
  target    = "integrations/${aws_apigatewayv2_integration.employee_lambda.id}"
}
