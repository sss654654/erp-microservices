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
resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "dev"
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

# Integrations
resource "aws_apigatewayv2_integration" "employee" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["employee"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/employees/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_integration" "employee_root" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["employee"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/employees"
  }
}

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

# Routes
resource "aws_apigatewayv2_route" "employee" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/employees/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.employee.id}"
}

resource "aws_apigatewayv2_route" "employee_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/employees"
  target    = "integrations/${aws_apigatewayv2_integration.employee_root.id}"
}

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

# Attendance Integration
resource "aws_apigatewayv2_integration" "attendance" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["employee"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/attendance/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_route" "attendance" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/attendance/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.attendance.id}"
}

# Quests Integration
resource "aws_apigatewayv2_integration" "quests" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["employee"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/quests/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_route" "quests" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/quests/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.quests.id}"
}

# Leaves Integration
resource "aws_apigatewayv2_integration" "leaves" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.nlb_listener_arns["employee"]
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "/leaves/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_route" "leaves" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /api/leaves/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.leaves.id}"
}
