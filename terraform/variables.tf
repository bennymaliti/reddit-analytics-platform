# ─────────────────────────────────────────────────
# Core
# ─────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Short name used as a prefix for all AWS resources"
  type        = string
  default     = "reddit-analytics"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────
# Reddit Ingestion
# ─────────────────────────────────────────────────
variable "reddit_secret_name" {
  description = "Name of the Secrets Manager secret holding Reddit API credentials"
  type        = string
  default     = "reddit-analytics/api-credentials"
}

variable "reddit_subreddits" {
  description = "List of subreddits to monitor (plus 'all')"
  type        = list(string)
  default     = ["all", "technology", "worldnews", "science", "AskReddit", "programming"]
}

variable "ingestion_rate_minutes" {
  description = "EventBridge schedule rate for Reddit polling (minutes)"
  type        = number
  default     = 5
  validation {
    condition     = var.ingestion_rate_minutes >= 1 && var.ingestion_rate_minutes <= 60
    error_message = "ingestion_rate_minutes must be between 1 and 60."
  }
}

variable "posts_per_run" {
  description = "Number of posts to fetch per ingestion run per subreddit"
  type        = number
  default     = 100
}

# ─────────────────────────────────────────────────
# Kinesis
# ─────────────────────────────────────────────────
variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis Data Streams"
  type        = number
  default     = 2
}

variable "kinesis_retention_hours" {
  description = "Kinesis stream data retention period (hours)"
  type        = number
  default     = 24
}

variable "firehose_buffer_size_mb" {
  description = "Kinesis Firehose buffer size (MB) before delivery to S3"
  type        = number
  default     = 64
}

variable "firehose_buffer_interval_sec" {
  description = "Kinesis Firehose buffer interval (seconds)"
  type        = number
  default     = 300
}

# ─────────────────────────────────────────────────
# DynamoDB
# ─────────────────────────────────────────────────
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST | PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_raw_posts_ttl_days" {
  description = "TTL for raw posts in DynamoDB (days)"
  type        = number
  default     = 30
}

variable "dynamodb_trending_ttl_days" {
  description = "TTL for trending topic entries in DynamoDB (days)"
  type        = number
  default     = 7
}

# ─────────────────────────────────────────────────
# Lambda
# ─────────────────────────────────────────────────
variable "lambda_log_retention_days" {
  description = "CloudWatch log retention for Lambda functions (days)"
  type        = number
  default     = 30
}

variable "lambda_tracing_mode" {
  description = "X-Ray tracing mode for Lambda (Active | PassThrough)"
  type        = string
  default     = "Active"
}

# ─────────────────────────────────────────────────
# Alerts
# ─────────────────────────────────────────────────
variable "alert_email" {
  description = "Email address for CloudWatch alarm SNS notifications"
  type        = string
  default     = ""
}

variable "kinesis_iterator_age_alarm_seconds" {
  description = "Kinesis iterator age alarm threshold (seconds)"
  type        = number
  default     = 60
}

variable "lambda_error_rate_alarm_percent" {
  description = "Lambda error rate alarm threshold (percent)"
  type        = number
  default     = 5
}

# ─────────────────────────────────────────────────
# API Gateway
# ─────────────────────────────────────────────────
variable "api_throttle_rate_limit" {
  description = "API Gateway steady-state rate limit (requests/second)"
  type        = number
  default     = 1000
}

variable "api_throttle_burst_limit" {
  description = "API Gateway burst rate limit (requests/second)"
  type        = number
  default     = 2000
}
