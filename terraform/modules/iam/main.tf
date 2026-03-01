data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "base" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.name_prefix}-*"]
  }
}

resource "aws_iam_policy" "base" {
  name   = "${var.name_prefix}-lambda-base"
  policy = data.aws_iam_policy_document.base.json
}

# --- Ingestion Role ---
resource "aws_iam_role" "ingestion" {
  name               = "${var.name_prefix}-ingestion"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "ingestion_base" {
  role       = aws_iam_role.ingestion.name
  policy_arn = aws_iam_policy.base.arn
}

resource "aws_iam_role_policy" "ingestion" {
  name = "${var.name_prefix}-ingestion"
  role = aws_iam_role.ingestion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = [var.kinesis_raw_stream_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${var.s3_raw_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.reddit_secret_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = var.dynamodb_table_arns
      },
    ]
  })
}

# --- Sentiment Role ---
resource "aws_iam_role" "sentiment" {
  name               = "${var.name_prefix}-sentiment"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "sentiment_base" {
  role       = aws_iam_role.sentiment.name
  policy_arn = aws_iam_policy.base.arn
}

resource "aws_iam_role_policy" "sentiment" {
  name = "${var.name_prefix}-sentiment"
  role = aws_iam_role.sentiment.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ]
        Resource = [var.kinesis_raw_stream_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = var.dynamodb_table_arns
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:BatchDetectSentiment",
          "comprehend:DetectKeyPhrases"
        ]
        Resource = ["*"]
      },
    ]
  })
}

# --- Trending Role ---
resource "aws_iam_role" "trending" {
  name               = "${var.name_prefix}-trending"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "trending_base" {
  role       = aws_iam_role.trending.name
  policy_arn = aws_iam_policy.base.arn
}

resource "aws_iam_role_policy" "trending" {
  name = "${var.name_prefix}-trending"
  role = aws_iam_role.trending.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ]
        Resource = [var.kinesis_raw_stream_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = var.dynamodb_table_arns
      },
      {
        Effect   = "Allow"
        Action   = ["comprehend:DetectKeyPhrases", "comprehend:DetectEntities"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_trending_arn]
      },
    ]
  })
}

# --- Consumer Roles (engagement, classification, author-profiling) ---
resource "aws_iam_role" "consumer" {
  for_each           = toset(["engagement", "classification", "author-profiling"])
  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "consumer_base" {
  for_each   = aws_iam_role.consumer
  role       = each.value.name
  policy_arn = aws_iam_policy.base.arn
}

resource "aws_iam_role_policy" "consumer" {
  for_each = aws_iam_role.consumer
  name     = "${var.name_prefix}-${each.key}"
  role     = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ]
        Resource = [var.kinesis_raw_stream_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = var.dynamodb_table_arns
      },
      {
        Effect   = "Allow"
        Action   = ["comprehend:DetectEntities", "comprehend:DetectKeyPhrases"]
        Resource = ["*"]
      },
    ]
  })
}

# --- Analytics API Role ---
resource "aws_iam_role" "analytics_api" {
  name               = "${var.name_prefix}-analytics-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "analytics_api_base" {
  role       = aws_iam_role.analytics_api.name
  policy_arn = aws_iam_policy.base.arn
}

resource "aws_iam_role_policy" "analytics_api" {
  name = "${var.name_prefix}-analytics-api"
  role = aws_iam_role.analytics_api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = flatten([
          var.dynamodb_table_arns,
          [for arn in var.dynamodb_table_arns : "${arn}/index/*"]
        ])
      },
    ]
  })
}