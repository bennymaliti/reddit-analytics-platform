data "aws_region" "current" {}

resource "aws_kinesis_stream" "raw_posts" {
  name             = "${var.name_prefix}-raw-posts"
  shard_count      = var.shard_count
  retention_period = var.retention_period_hours
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_id
  tags             = { Name = "${var.name_prefix}-raw-posts" }
}

resource "aws_kinesis_stream" "analytics" {
  name             = "${var.name_prefix}-analytics"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = var.kms_key_id
  tags             = { Name = "${var.name_prefix}-analytics" }
}

data "aws_iam_policy_document" "firehose_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${var.name_prefix}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

data "aws_iam_policy_document" "firehose_policy" {
  statement {
    effect = "Allow"
    actions = ["kinesis:GetRecords", "kinesis:GetShardIterator",
    "kinesis:DescribeStream", "kinesis:ListShards"]
    resources = [aws_kinesis_stream.raw_posts.arn]
  }
  statement {
    effect = "Allow"
    actions = ["s3:AbortMultipartUpload", "s3:GetBucketLocation",
    "s3:GetObject", "s3:ListBucket", "s3:PutObject"]
    resources = [var.s3_processed_bucket_arn, "${var.s3_processed_bucket_arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "firehose" {
  name   = "${var.name_prefix}-firehose"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_policy.json
}

resource "aws_kinesis_firehose_delivery_stream" "to_s3" {
  name        = "${var.name_prefix}-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.raw_posts.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = var.s3_processed_bucket_arn
    buffering_size      = var.firehose_buffer_size_mb
    buffering_interval  = var.firehose_buffer_interval_sec
    compression_format  = "UNCOMPRESSED"
    prefix              = "firehose/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "firehose-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/"
  }

  tags = { Name = "${var.name_prefix}-firehose" }
}
