output "api_gateway_id" {
  description = "HTTP API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "api_gateway_invoke_url" {
  description = "HTTP API Gateway Invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_gateway_endpoint" {
  description = "HTTP API Gateway Endpoint"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/api/v1"
}

output "vpc_link_id" {
  description = "VPC Link ID"
  value       = aws_apigatewayv2_vpc_link.main.id
}
