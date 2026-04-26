output "sns_topic_arn" {
  description = "ARN do SNS Topic de alertas"
  value       = aws_sns_topic.alerts.arn
}

output "app_log_group_name" {
  description = "Nome do Log Group da aplicação"
  value       = aws_cloudwatch_log_group.app.name
}

output "dashboard_name" {
  description = "Nome do CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "guardduty_detector_id" {
  description = "ID do detector do GuardDuty"
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : ""
}
