output "nlb_arn" {
  value = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  value = aws_lb.nlb.dns_name
}

output "target_group_arns" {
  value = {
    approval_request    = aws_lb_target_group.approval_request.arn
    approval_processing = aws_lb_target_group.approval_processing.arn
    notification        = aws_lb_target_group.notification.arn
  }
}

output "listener_arns" {
  value = {
    approval_request    = aws_lb_listener.approval_request.arn
    approval_processing = aws_lb_listener.approval_processing.arn
    notification        = aws_lb_listener.notification.arn
  }
}
