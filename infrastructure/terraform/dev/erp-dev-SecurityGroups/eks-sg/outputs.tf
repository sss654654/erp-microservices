output "sg_id" {
  description = "EKS Security Group ID"
  value       = aws_security_group.eks.id
}
