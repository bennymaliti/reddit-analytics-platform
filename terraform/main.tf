# ═══════════════════════════════════════════════════════════════════
# Reddit Analytics Platform — Root Terraform Module
# ═══════════════════════════════════════════════════════════════════

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── KMS Customer Managed Key ───
resource "aws_kms_key" "main" {
  description             = "CMK for ${local.name_prefix}"
  deletion_window_in_days = 14
  enable_key_rotation     = true
  tags                    = { Name = "${local.name_prefix}-cmk" }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# ─── SNS Topics ───
resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-alerts"
  kms_master_key_id = aws_kms_key.main.id
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic" "trending_spikes" {
  name              = "${local.name_prefix}-trending-spikes"
  kms_master_key_id = aws_kms_key.main.id
}

# ─── S3 Buckets ───
module "s3" {
  source      = "./modules/s3"
  name_prefix = local.name_prefix
  kms_key_arn = aws_kms_key.main.arn
}

# ─── DynamoDB Tables ───
module "dynamodb" {
  source             = "./modules/dynamodb"
  name_prefix        = local.name_prefix
  kms_key_arn        = aws_kms_key.main.arn
  billing_mode       = var.dynamodb_billing_mode
  raw_posts_ttl_days = var.dynamodb_raw_posts_ttl_days
  trending_ttl_days  = var.dynamodb_trending_ttl_days
}

# ─── Kinesis Streams ───
module "kinesis" {
  source                       = "./modules/kinesis"
  name_prefix                  = local.name_prefix
  kms_key_id                   = aws_kms_key.main.id
  kms_key_arn                  = aws_kms_key.main.arn
  shard_count                  = var.kinesis_shard_count
  retention_period_hours       = var.kinesis_retention_hours
  s3_processed_bucket_arn      = module.s3.processed_bucket_arn
  s3_processed_bucket_id       = module.s3.processed_bucket_name
  firehose_buffer_size_mb      = var.firehose_buffer_size_mb
  firehose_buffer_interval_sec = var.firehose_buffer_interval_sec
}

# ─── IAM Roles ───
module "iam" {
  source                  = "./modules/iam"
  name_prefix             = local.name_prefix
  aws_region              = var.aws_region
  kms_key_arn             = aws_kms_key.main.arn
  kinesis_raw_stream_arn  = module.kinesis.raw_stream_arn
  s3_raw_bucket_arn       = module.s3.raw_bucket_arn
  s3_artifacts_bucket_arn = module.s3.artifacts_bucket_arn
  dynamodb_table_arns     = module.dynamodb.table_arns
  sns_alerts_arn          = aws_sns_topic.alerts.arn
  sns_trending_arn        = aws_sns_topic.trending_spikes.arn
  reddit_secret_arn       = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.reddit_secret_name}*"
}

# ─── Lambda Functions ───
module "lambda" {
  source                  = "./modules/lambda"
  name_prefix             = local.name_prefix
  s3_artifacts_bucket     = module.s3.artifacts_bucket_name
  kinesis_raw_stream_arn  = module.kinesis.raw_stream_arn
  kinesis_raw_stream_name = module.kinesis.raw_stream_name
  s3_raw_bucket           = module.s3.raw_bucket_name
  dynamodb_table_names    = module.dynamodb.table_names
  sns_alerts_arn          = aws_sns_topic.alerts.arn
  sns_trending_arn        = aws_sns_topic.trending_spikes.arn
  reddit_secret_name      = var.reddit_secret_name
  reddit_subreddits       = jsonencode(var.reddit_subreddits)
  posts_per_run           = var.posts_per_run
  iam_roles               = module.iam.lambda_role_arns
  log_retention_days      = var.lambda_log_retention_days
  tracing_mode            = var.lambda_tracing_mode
  aws_region              = var.aws_region
}

# ─── EventBridge Schedule ───
module "eventbridge" {
  source                = "./modules/eventbridge"
  name_prefix           = local.name_prefix
  ingestion_lambda_arn  = module.lambda.function_arns["data_ingestion"]
  ingestion_lambda_name = module.lambda.function_names["data_ingestion"]
  rate_minutes          = var.ingestion_rate_minutes
}

# ─── API Gateway + Cognito ───
module "api_gateway" {
  source                = "./modules/api_gateway"
  name_prefix           = local.name_prefix
  environment           = var.environment
  analytics_lambda_arn  = module.lambda.function_arns["api_handler"]
  analytics_lambda_name = module.lambda.function_names["api_handler"]
  throttle_rate_limit   = var.api_throttle_rate_limit
  throttle_burst_limit  = var.api_throttle_burst_limit
  aws_region            = var.aws_region
}

# ─── Glue Catalog + ETL ───
module "glue" {
  source                   = "./modules/glue"
  name_prefix              = local.name_prefix
  s3_processed_bucket_name = module.s3.processed_bucket_name
  s3_scripts_bucket_name   = module.s3.artifacts_bucket_name
  kms_key_arn              = aws_kms_key.main.arn
}

# ─── CloudWatch Alarms ───
resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
  alarm_name          = "${local.name_prefix}-kinesis-iterator-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.kinesis_iterator_age_alarm_seconds * 1000
  alarm_description   = "Kinesis consumer falling behind"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { StreamName = module.kinesis.raw_stream_name }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name_prefix
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          title  = "Lambda Invocations & Errors"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${local.name_prefix}-data-ingestion"],
            ["AWS/Lambda", "Errors", "FunctionName", "${local.name_prefix}-data-ingestion"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${local.name_prefix}-sentiment-analysis"],
            ["AWS/Lambda", "Errors", "FunctionName", "${local.name_prefix}-sentiment-analysis"],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          title  = "Kinesis Iterator Age"
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/Kinesis", "GetRecords.IteratorAgeMilliseconds",
            "StreamName", "${local.name_prefix}-raw-posts"]
          ]
        }
      }
    ]
  })
}
