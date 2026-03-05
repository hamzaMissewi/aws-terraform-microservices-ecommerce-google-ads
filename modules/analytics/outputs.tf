output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB analytics table"
  value       = aws_dynamodb_table.analytics.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB analytics table"
  value       = aws_dynamodb_table.analytics.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key for analytics"
  value       = aws_kms_key.analytics.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key for analytics"
  value       = aws_kms_alias.analytics.name
}

output "lambda_function_arn" {
  description = "ARN of the analytics Lambda function"
  value       = aws_lambda_function.analytics_processor.arn
}

output "lambda_function_name" {
  description = "Name of the analytics Lambda function"
  value       = aws_lambda_function.analytics_processor.function_name
}
