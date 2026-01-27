output "dynamodb_table_name" {
  description = "Name of the DynamoDB table storing logs"
  value       = aws_dynamodb_table.logs.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.logs.arn
}

output "ingest_lambda_function_name" {
  description = "Name of the Ingest Lambda function"
  value       = aws_lambda_function.ingest.function_name
}

output "ingest_lambda_arn" {
  description = "ARN of the Ingest Lambda function"
  value       = aws_lambda_function.ingest.arn
}

output "ingest_lambda_url" {
  description = "Function URL for the Ingest Lambda (use this to ingest logs)"
  value       = aws_lambda_function_url.ingest.function_url
}

output "read_recent_lambda_function_name" {
  description = "Name of the ReadRecent Lambda function"
  value       = aws_lambda_function.read_recent.function_name
}

output "read_recent_lambda_arn" {
  description = "ARN of the ReadRecent Lambda function"
  value       = aws_lambda_function.read_recent.arn
}

output "read_recent_lambda_url" {
  description = "Function URL for the ReadRecent Lambda (use this to retrieve logs)"
  value       = aws_lambda_function_url.read_recent.function_url
}

output "deployment_region" {
  description = "AWS region where resources were deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "cloudwatch_log_group_ingest" {
  description = "CloudWatch Log Group for Ingest Lambda"
  value       = aws_cloudwatch_log_group.ingest_lambda_logs.name
}

output "cloudwatch_log_group_read_recent" {
  description = "CloudWatch Log Group for ReadRecent Lambda"
  value       = aws_cloudwatch_log_group.read_recent_lambda_logs.name
}
