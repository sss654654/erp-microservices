output "employee_lambda_repository_url" {
  description = "ECR repository URL for employee Lambda"
  value       = aws_ecr_repository.employee_lambda.repository_url
}

output "employee_lambda_repository_arn" {
  description = "ECR repository ARN for employee Lambda"
  value       = aws_ecr_repository.employee_lambda.arn
}

output "eks_services_repository_urls" {
  description = "ECR repository URLs for EKS services"
  value       = { for k, v in aws_ecr_repository.eks_services : k => v.repository_url }
}

output "eks_services_repository_arns" {
  description = "ECR repository ARNs for EKS services"
  value       = { for k, v in aws_ecr_repository.eks_services : k => v.arn }
}
