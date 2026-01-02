# VPC Link
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-${var.environment}-vpc-link"
  security_group_ids = var.security_group_ids
  subnet_ids         = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-link"
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-api"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-api-logs"
  }
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

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
    Name = "${var.project_name}-${var.environment}-api-stage"
  }
}

# Integrations (3개 EKS 서비스만 - Employee는 Lambda 모듈에서 처리)
resource "aws_apigatewayv2_integration" "approval_request" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["approval_request"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/approvals/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_integration" "approval_request_root" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["approval_request"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/approvals"
  }
}

resource "aws_apigatewayv2_integration" "approval_processing" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["approval_processing"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/process/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_integration" "notification" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["notification"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/notifications/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_integration" "notification_root" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["notification"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/notifications"
  }
}

# Routes (3개 EKS 서비스만 - Employee는 Lambda 모듈에서 처리)
resource "aws_apigatewayv2_route" "approval_request" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/approvals/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_request.id}"
}

resource "aws_apigatewayv2_route" "approval_request_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/approvals"
  target    = "integrations/${aws_apigatewayv2_integration.approval_request_root.id}"
}

resource "aws_apigatewayv2_route" "approval_processing" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/process/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_processing.id}"
}

resource "aws_apigatewayv2_route" "notification" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/notifications/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.notification.id}"
}

resource "aws_apigatewayv2_route" "notification_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/notifications"
  target    = "integrations/${aws_apigatewayv2_integration.notification_root.id}"
}

# Employee, Attendance, Quests, Leaves는 Lambda 모듈에서 처리
