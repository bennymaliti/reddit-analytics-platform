aws_region   = "eu-west-2"
environment  = "dev"
project_name = "reddit-analytics"

reddit_subreddits      = ["programming", "aws"]
ingestion_rate_minutes = 10
posts_per_run          = 25

kinesis_shard_count          = 1
kinesis_retention_hours      = 24
firehose_buffer_size_mb      = 64
firehose_buffer_interval_sec = 300

dynamodb_billing_mode       = "PAY_PER_REQUEST"
dynamodb_raw_posts_ttl_days = 7
dynamodb_trending_ttl_days  = 3

lambda_log_retention_days = 7
lambda_tracing_mode       = "Active"

alert_email                        = "your-email@example.com"
kinesis_iterator_age_alarm_seconds = 120
lambda_error_rate_alarm_percent    = 10

api_throttle_rate_limit  = 100
api_throttle_burst_limit = 200

tags = {
  Owner      = "Benny Maliti"
  CostCenter = "analytics"
  Team       = "platform"
}
