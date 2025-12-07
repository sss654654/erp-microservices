output "mysql_secret_arn" {
  description = "ARN of MySQL secret"
  value       = aws_secretsmanager_secret.mysql.arn
}

output "mysql_secret_name" {
  description = "Name of MySQL secret"
  value       = aws_secretsmanager_secret.mysql.name
}
