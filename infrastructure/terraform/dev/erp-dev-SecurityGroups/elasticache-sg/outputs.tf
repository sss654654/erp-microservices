output "sg_id" {
  description = "ElastiCache Security Group ID"
  value       = aws_security_group.elasticache.id
}
