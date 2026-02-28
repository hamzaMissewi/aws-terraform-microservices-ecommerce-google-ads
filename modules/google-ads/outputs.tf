output "google_ads_lambda_role_arn" {
  description = "ARN of the Google Ads Lambda IAM role"
  value       = aws_iam_role.google_ads_lambda_role.arn
}

output "campaign_monitor_function_name" {
  description = "Name of the campaign monitor Lambda function"
  value       = aws_lambda_function.campaign_monitor.function_name
}

output "campaign_monitor_function_arn" {
  description = "ARN of the campaign monitor Lambda function"
  value       = aws_lambda_function.campaign_monitor.arn
}

output "bid_optimizer_function_name" {
  description = "Name of the bid optimizer Lambda function"
  value       = aws_lambda_function.bid_optimizer.function_name
}

output "bid_optimizer_function_arn" {
  description = "ARN of the bid optimizer Lambda function"
  value       = aws_lambda_function.bid_optimizer.arn
}

output "ad_analytics_function_name" {
  description = "Name of the ad analytics Lambda function"
  value       = aws_lambda_function.ad_analytics.function_name
}

output "ad_analytics_function_arn" {
  description = "ARN of the ad analytics Lambda function"
  value       = aws_lambda_function.ad_analytics.arn
}

output "google_ads_credentials_secret_arn" {
  description = "ARN of the Google Ads credentials secret"
  value       = aws_secretsmanager_secret.google_ads_credentials.arn
}

output "campaign_monitor_schedule_arn" {
  description = "ARN of the campaign monitor CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.campaign_monitor_schedule.arn
}

output "bid_optimizer_schedule_arn" {
  description = "ARN of the bid optimizer CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.bid_optimizer_schedule.arn
}

output "log_group_names" {
  description = "Names of the CloudWatch log groups"
  value = {
    campaign_monitor = aws_cloudwatch_log_group.campaign_monitor_logs.name
    bid_optimizer     = aws_cloudwatch_log_group.bid_optimizer_logs.name
    ad_analytics      = aws_cloudwatch_log_group.ad_analytics_logs.name
  }
}
