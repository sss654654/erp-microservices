data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/alb/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# HTTP API (API Gateway v2)
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "ERP Microservices HTTP API Gateway"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api"
    Environment = var.environment
  }
}

# VPC Link for HTTP API (Private ALB 연결)
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-${var.environment}-vpc-link"
  security_group_ids = [data.terraform_remote_state.alb.outputs.alb_sg_id]
  subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc-link"
    Environment = var.environment
  }
}

# ALB Integration
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = data.terraform_remote_state.alb.outputs.alb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id

  request_parameters = {
    "overwrite:path" = "$request.path"
  }
}

# Routes - Employee Service
resource "aws_apigatewayv2_route" "employees" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/v1/employees/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Routes - Approval Request Service
resource "aws_apigatewayv2_route" "approvals" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/v1/approvals/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Routes - Approval Processing Service
resource "aws_apigatewayv2_route" "process" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/v1/process/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Routes - Notification Service
resource "aws_apigatewayv2_route" "notifications" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/v1/notifications/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Stage (자동 배포)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 300
    logging_level          = "INFO"
    data_trace_enabled     = true
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-stage"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-logs"
    Environment = var.environment
  }
}
