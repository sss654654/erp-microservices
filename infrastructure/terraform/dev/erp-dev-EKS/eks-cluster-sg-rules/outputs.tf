output "cluster_security_group_id" {
  description = "EKS Cluster Security Group ID"
  value       = data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}
