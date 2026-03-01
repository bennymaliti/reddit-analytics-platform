# ─────────────────────────────────────────────────
# API Gateway
# ─────────────────────────────────────────────────
output "api_gateway_url" {
  description = "Base URL of the Analytics REST API"
  value       = "${module.api_gateway.api_gateway_url}/${var.environment}"
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_gateway_id
}

# ─────────────────────────────────────────────────
# Cognito
# ─────────────────────────────────────────────────
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.api_gateway.cognito_user_pool_id
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID"
  value       = module.api_gateway.cognito_app_client_id
  sensitive   = true
}

# ─────────────────────────────────────────────────
# Kinesis
# ─────────────────────────────────────────────────
output "kinesis_raw_stream_name" {
  description = "Kinesis raw posts stream name"
  value       = module.kinesis.raw_stream_name
}

output "kinesis_raw_stream_arn" {
  description = "Kinesis raw posts stream ARN"
  value       = module.kinesis.raw_stream_arn
}

# ─────────────────────────────────────────────────
# S3
# ─────────────────────────────────────────────────
output "s3_raw_bucket_name" {
  description = "S3 bucket name for raw Reddit data archive"
  value       = module.s3.raw_bucket_name
}

output "s3_processed_bucket_name" {
  description = "S3 bucket name for processed Parquet data"
  value       = module.s3.processed_bucket_name
}

output "s3_artifacts_bucket_name" {
  description = "S3 bucket name for Lambda deployment artifacts"
  value       = module.s3.artifacts_bucket_name
}

# ─────────────────────────────────────────────────
# Lambda ARNs
# ─────────────────────────────────────────────────
output "lambda_arns" {
  description = "ARNs of all deployed Lambda functions"
  value       = module.lambda.function_arns
}

# ─────────────────────────────────────────────────
# DynamoDB
# ─────────────────────────────────────────────────
output "dynamodb_table_names" {
  description = "Names of all DynamoDB tables"
  value       = module.dynamodb.table_names
}

# ─────────────────────────────────────────────────
# CloudWatch
# ─────────────────────────────────────────────────
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch monitoring dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-${var.environment}"
}
