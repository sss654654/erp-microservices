output "role_arn" {
  description = "EKS Cluster Role ARN"
  value       = aws_iam_role.eks_cluster.arn
}

output "role_name" {
  description = "EKS Cluster Role Name"
  value       = aws_iam_role.eks_cluster.name
}
