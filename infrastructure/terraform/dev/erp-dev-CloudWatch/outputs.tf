output "sns_topic_arn" {
  description = "SNS Topic ARN for alarms"
  value       = aws_sns_topic.erp_alarms.arn
}

output "sns_topic_name" {
  description = "SNS Topic name"
  value       = aws_sns_topic.erp_alarms.name
}

output "alarm_names" {
  description = "CloudWatch Alarm names"
  value = {
    error_alarm   = aws_cloudwatch_metric_alarm.high_error_rate.alarm_name
    restart_alarm = aws_cloudwatch_metric_alarm.pod_restart_alarm.alarm_name
    lambda_alarm  = aws_cloudwatch_metric_alarm.lambda_error_rate.alarm_name
  }
}

output "email_subscription" {
  description = "Email subscription confirmation required"
  value       = "Check email: subinhong0109@dankook.ac.kr"
}
