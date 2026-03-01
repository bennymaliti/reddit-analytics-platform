locals {
  functions = {
    data_ingestion = {
      handler     = "handler.lambda_handler"
      memory      = 512
      timeout     = 300
      description = "Ingests Reddit posts via PRAW and publishes to Kinesis"
      source_dir  = "data_ingestion"
      role_key    = "ingestion"
    }
    sentiment_analysis = {
      handler     = "handler.lambda_handler"
      memory      = 256
      timeout     = 180
      description = "Sentiment analysis via Amazon Comprehend"
      source_dir  = "sentiment_analysis"
      role_key    = "sentiment"
    }
    trending_topics = {
      handler     = "handler.lambda_handler"
      memory      = 256
      timeout     = 180
      description = "Trending topic detection with rolling windows"
      source_dir  = "trending_topics"
      role_key    = "trending"
    }
    engagement_scoring = {
      handler     = "handler.lambda_handler"
      memory      = 256
      timeout     = 180
      description = "Composite engagement score calculation"
      source_dir  = "engagement_scoring"
      role_key    = "engagement"
    }
    content_classification = {
      handler     = "handler.lambda_handler"
      memory      = 256
      timeout     = 180
      description = "Content type and topic classification"
      source_dir  = "content_classification"
      role_key    = "classification"
    }
    author_profiling = {
      handler     = "handler.lambda_handler"
      memory      = 256
      timeout     = 180
      description = "Author behavioural profile aggregation"
      source_dir  = "author_profiling"
      role_key    = "author_profiling"
    }
    api_handler = {
      handler     = "handler.lambda_handler"
      memory      = 512
      timeout     = 30
      description = "Unified REST API for analytics query results"
      source_dir  = "api_handler"
      role_key    = "analytics_api"
    }
  }
}

data "archive_file" "lambda_zip" {
  for_each    = local.functions
  type        = "zip"
  source_dir  = "${path.root}/../src/lambdas/${each.value.source_dir}"
  output_path = "${path.module}/dist/${each.key}.zip"
}

resource "aws_s3_object" "lambda_zip" {
  for_each = local.functions
  bucket   = var.s3_artifacts_bucket
  key      = "lambda/${each.key}/${each.key}-${data.archive_file.lambda_zip[each.key].output_md5}.zip"
  source   = data.archive_file.lambda_zip[each.key].output_path
  etag     = data.archive_file.lambda_zip[each.key].output_md5
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each          = local.functions
  name              = "/aws/lambda/${var.name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "functions" {
  for_each      = local.functions
  function_name = "${var.name_prefix}-${each.key}"
  description   = each.value.description
  role          = var.iam_roles[each.value.role_key]
  s3_bucket     = var.s3_artifacts_bucket
  s3_key        = aws_s3_object.lambda_zip[each.key].key
  runtime       = "python3.12"
  handler       = each.value.handler
  memory_size   = each.value.memory
  timeout       = each.value.timeout
  architectures = ["arm64"]

  tracing_config { mode = var.tracing_mode }

  environment {
    variables = {
      KINESIS_RAW_STREAM           = var.kinesis_raw_stream_name
      S3_RAW_BUCKET                = var.s3_raw_bucket
      DYNAMODB_RAW_POSTS           = var.dynamodb_table_names["raw_posts"]
      DYNAMODB_SENTIMENT           = var.dynamodb_table_names["sentiment"]
      DYNAMODB_TRENDING            = var.dynamodb_table_names["trending"]
      DYNAMODB_ENGAGEMENT          = var.dynamodb_table_names["engagement"]
      DYNAMODB_AUTHORS             = var.dynamodb_table_names["authors"]
      SNS_ALERTS_ARN               = var.sns_alerts_arn
      SNS_TRENDING_ARN             = var.sns_trending_arn
      REDDIT_SECRET_NAME           = var.reddit_secret_name
      REDDIT_SUBREDDITS            = var.reddit_subreddits
      POSTS_PER_RUN                = tostring(var.posts_per_run)
      POWERTOOLS_METRICS_NAMESPACE = "reddit-analytics"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

locals {
  kinesis_consumers = ["sentiment_analysis", "trending_topics", "engagement_scoring",
  "content_classification", "author_profiling"]
}

resource "aws_sqs_queue" "dlq" {
  for_each                  = toset(local.kinesis_consumers)
  name                      = "${var.name_prefix}-${each.key}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_lambda_event_source_mapping" "kinesis" {
  for_each                           = toset(local.kinesis_consumers)
  event_source_arn                   = var.kinesis_raw_stream_arn
  function_name                      = aws_lambda_function.functions[each.key].arn
  starting_position                  = "LATEST"
  batch_size                         = 100
  maximum_batching_window_in_seconds = 30
  bisect_batch_on_function_error     = true

  destination_config {
    on_failure { destination_arn = aws_sqs_queue.dlq[each.key].arn }
  }
}
