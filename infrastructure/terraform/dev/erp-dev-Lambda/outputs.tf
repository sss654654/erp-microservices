output "lambda_function_arn" {
  value = aws_lambda_function.employee.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.employee.function_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.employee_lambda.repository_url
}
