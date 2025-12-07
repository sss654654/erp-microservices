output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "eks_sg_id" {
  description = "EKS Security Group ID"
  value       = aws_security_group.eks.id
}

output "rds_sg_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "elasticache_sg_id" {
  description = "ElastiCache Security Group ID"
  value       = aws_security_group.elasticache.id
}
