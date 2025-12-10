output "sg_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}
