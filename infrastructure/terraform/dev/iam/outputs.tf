# EKS IAM Roles
output "eks_cluster_role_arn" {
  description = "ARN of EKS Cluster IAM Role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of EKS Node IAM Role"
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_role_name" {
  description = "Name of EKS Node IAM Role"
  value       = aws_iam_role.eks_node.name
}

# CodeBuild IAM Role
output "codebuild_role_arn" {
  description = "ARN of CodeBuild IAM Role"
  value       = aws_iam_role.codebuild.arn
}

output "codebuild_role_name" {
  description = "Name of CodeBuild IAM Role"
  value       = aws_iam_role.codebuild.name
}
