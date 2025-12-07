output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_listener_arn" {
  description = "ALB HTTP Listener ARN"
  value       = aws_lb_listener.http.arn
}

output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = data.terraform_remote_state.security.outputs.alb_sg_id
}

output "employee_tg_arn" {
  description = "Employee service target group ARN"
  value       = aws_lb_target_group.employee.arn
}

output "approval_request_tg_arn" {
  description = "Approval request service target group ARN"
  value       = aws_lb_target_group.approval_request.arn
}

output "approval_processing_tg_arn" {
  description = "Approval processing service target group ARN"
  value       = aws_lb_target_group.approval_processing.arn
}

output "notification_tg_arn" {
  description = "Notification service target group ARN"
  value       = aws_lb_target_group.notification.arn
}
