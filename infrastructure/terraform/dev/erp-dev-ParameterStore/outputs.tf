output "parameter_names" {
  description = "List of all parameter names"
  value = [
    aws_ssm_parameter.account_id.name,
    aws_ssm_parameter.region.name,
    aws_ssm_parameter.eks_cluster_name.name,
    aws_ssm_parameter.ecr_repository_prefix.name,
    aws_ssm_parameter.project_name.name,
    aws_ssm_parameter.environment.name
  ]
}

output "parameter_arns" {
  description = "Map of parameter ARNs"
  value = {
    account_id             = aws_ssm_parameter.account_id.arn
    region                 = aws_ssm_parameter.region.arn
    eks_cluster_name       = aws_ssm_parameter.eks_cluster_name.arn
    ecr_repository_prefix  = aws_ssm_parameter.ecr_repository_prefix.arn
    project_name           = aws_ssm_parameter.project_name.arn
    environment            = aws_ssm_parameter.environment.arn
  }
}
