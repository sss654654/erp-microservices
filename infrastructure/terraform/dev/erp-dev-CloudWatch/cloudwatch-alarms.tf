terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/cloudwatch/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ========================================
# SNS Topic for Alarms
# ========================================

resource "aws_sns_topic" "erp_alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-alarms"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "erp_alarms_email" {
  topic_arn = aws_sns_topic.erp_alarms.arn
  protocol  = "email"
  endpoint  = "subinhong0109@dankook.ac.kr"
}

# ========================================
# CloudWatch Metric Filters
# ========================================

# ERROR 로그 카운트
resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = "/aws/eks/${var.project_name}-${var.environment}/application"
  
  pattern = "ERROR"
  
  metric_transformation {
    name          = "ErrorCount"
    namespace     = "ERP/Application"
    value         = "1"
    default_value = 0
  }
}

# Pod 재시작 감지
resource "aws_cloudwatch_log_metric_filter" "pod_restarts" {
  name           = "${var.project_name}-${var.environment}-pod-restarts"
  log_group_name = "/aws/eks/${var.project_name}-${var.environment}/application"
  
  pattern = "?restart ?killed ?crash ?OOMKilled ?CrashLoopBackOff"
  
  metric_transformation {
    name          = "PodRestartCount"
    namespace     = "ERP/Application"
    value         = "1"
    default_value = 0
  }
}

# ========================================
# CloudWatch Alarms
# ========================================

# ERROR 로그 알람 (5분 동안 10회 이상)
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "ERP/Application"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ERROR 로그가 5분 동안 10회 이상 발생"
  treat_missing_data  = "notBreaching"
  
  alarm_actions = [aws_sns_topic.erp_alarms.arn]
  ok_actions    = [aws_sns_topic.erp_alarms.arn]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-high-error-rate"
    Environment = var.environment
    Severity    = "High"
    ManagedBy   = "Terraform"
  }
  
  depends_on = [aws_cloudwatch_log_metric_filter.error_logs]
}

# Pod 재시작 알람 (10분 동안 3회 이상)
resource "aws_cloudwatch_metric_alarm" "pod_restart_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-pod-restarts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "PodRestartCount"
  namespace           = "ERP/Application"
  period              = 600
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Pod가 10분 동안 3회 이상 재시작"
  treat_missing_data  = "notBreaching"
  
  alarm_actions = [aws_sns_topic.erp_alarms.arn]
  ok_actions    = [aws_sns_topic.erp_alarms.arn]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-pod-restarts"
    Environment = var.environment
    Severity    = "Critical"
    ManagedBy   = "Terraform"
  }
  
  depends_on = [aws_cloudwatch_log_metric_filter.pod_restarts]
}

# Lambda 에러율 알람 (5분 동안 5% 이상)
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5
  alarm_description   = "Lambda 에러율이 5% 이상"
  treat_missing_data  = "notBreaching"
  
  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate"
    return_data = true
  }
  
  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.project_name}-${var.environment}-employee-service"
      }
    }
  }
  
  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.project_name}-${var.environment}-employee-service"
      }
    }
  }
  
  alarm_actions = [aws_sns_topic.erp_alarms.arn]
  ok_actions    = [aws_sns_topic.erp_alarms.arn]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda-error-rate"
    Environment = var.environment
    Severity    = "High"
    ManagedBy   = "Terraform"
  }
}
