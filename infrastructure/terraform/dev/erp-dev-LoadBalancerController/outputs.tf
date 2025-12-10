output "service_account_role_arn" {
  value       = aws_iam_role.lb_controller.arn
  description = "IAM Role ARN for AWS Load Balancer Controller"
}

output "helm_release_status" {
  value       = helm_release.lb_controller.status
  description = "Helm Release Status"
}

output "helm_release_version" {
  value       = helm_release.lb_controller.version
  description = "Helm Chart Version"
}
