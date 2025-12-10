output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.main.id
}

output "vpc_link_id" {
  value = aws_apigatewayv2_vpc_link.main.id
}
