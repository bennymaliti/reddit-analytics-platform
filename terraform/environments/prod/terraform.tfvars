aws_region   = "eu-west-2"
environment  = "prod"
project_name = "reddit-analytics"

reddit_secret_name     = "reddit-analytics/api-credentials"
reddit_subreddits      = ["all", "technology", "worldnews", "science", "programming", "MachineLearning", "aws"]
ingestion_rate_minutes = 5
posts_per_run          = 100

kinesis_shard_count          = 2
kinesis_retention_hours      = 24
firehose_buffer_size_mb      = 64
firehose_buffer_interval_sec = 300

dynamodb_billing_mode       = "PAY_PER_REQUEST"
dynamodb_raw_posts_ttl_days = 30
dynamodb_trending_ttl_days  = 7

lambda_log_retention_days = 30
lambda_tracing_mode       = "Active"

alert_email                        = "your-email@example.com"
kinesis_iterator_age_alarm_seconds = 60
lambda_error_rate_alarm_percent    = 5

api_throttle_rate_limit  = 1000
api_throttle_burst_limit = 2000

tags = {
  Owner      = "Benny Maliti"
  CostCenter = "analytics"
  Team       = "platform"
}
