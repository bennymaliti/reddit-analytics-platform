resource "aws_dynamodb_table" "raw_posts" {
  name         = "${var.name_prefix}-raw-posts"
  billing_mode = var.billing_mode
  hash_key     = "post_id"
  range_key    = "ingested_at"

  attribute {
    name = "post_id"
    type = "S"
  }

  attribute {
    name = "ingested_at"
    type = "S"
  }

  attribute {
    name = "subreddit"
    type = "S"
  }

  global_secondary_index {
    name            = "by-subreddit-index"
    hash_key        = "subreddit"
    range_key       = "ingested_at"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.name_prefix}-raw-posts" }
}

resource "aws_dynamodb_table" "sentiment" {
  name         = "${var.name_prefix}-sentiment"
  billing_mode = var.billing_mode
  hash_key     = "post_id"
  range_key    = "analyzed_at"

  attribute {
    name = "post_id"
    type = "S"
  }

  attribute {
    name = "analyzed_at"
    type = "S"
  }

  attribute {
    name = "sentiment"
    type = "S"
  }

  global_secondary_index {
    name               = "by-sentiment-index"
    hash_key           = "sentiment"
    range_key          = "analyzed_at"
    projection_type    = "INCLUDE"
    non_key_attributes = ["post_id", "positive_score", "negative_score"]
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.name_prefix}-sentiment" }
}

resource "aws_dynamodb_table" "trending" {
  name         = "${var.name_prefix}-trending"
  billing_mode = var.billing_mode
  hash_key     = "topic"
  range_key    = "window_ts"

  attribute {
    name = "topic"
    type = "S"
  }

  attribute {
    name = "window_ts"
    type = "S"
  }

  attribute {
    name = "window"
    type = "S"
  }

  attribute {
    name = "mention_count"
    type = "N"
  }

  global_secondary_index {
    name            = "by-count-index"
    hash_key        = "window"
    range_key       = "mention_count"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.name_prefix}-trending" }
}

resource "aws_dynamodb_table" "engagement" {
  name         = "${var.name_prefix}-engagement"
  billing_mode = var.billing_mode
  hash_key     = "post_id"
  range_key    = "scored_at"

  attribute {
    name = "post_id"
    type = "S"
  }

  attribute {
    name = "scored_at"
    type = "S"
  }

  attribute {
    name = "engagement_score"
    type = "N"
  }

  attribute {
    name = "subreddit"
    type = "S"
  }

  global_secondary_index {
    name            = "by-score-index"
    hash_key        = "subreddit"
    range_key       = "engagement_score"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.name_prefix}-engagement" }
}

resource "aws_dynamodb_table" "authors" {
  name         = "${var.name_prefix}-authors"
  billing_mode = var.billing_mode
  hash_key     = "author"
  range_key    = "profile_date"

  attribute {
    name = "author"
    type = "S"
  }

  attribute {
    name = "profile_date"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.name_prefix}-authors" }
}
