output "role_arn" {
  description = "EKS Node Role ARN"
  value       = aws_iam_role.eks_node.arn
}

output "role_name" {
  description = "EKS Node Role Name"
  value       = aws_iam_role.eks_node.name
}
