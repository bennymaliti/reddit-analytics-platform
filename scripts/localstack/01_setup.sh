#!/bin/bash
set -e

echo "Setting up LocalStack resources..."

AWS_CMD="aws --endpoint-url=http://localhost:4566 --region eu-west-2"

# --- Kinesis Streams ---
echo "Creating Kinesis streams..."
$AWS_CMD kinesis create-stream --stream-name reddit-analytics-local-raw-posts --shard-count 1
$AWS_CMD kinesis create-stream --stream-name reddit-analytics-local-analytics --shard-count 1

# --- DynamoDB Tables ---
echo "Creating DynamoDB tables..."
$AWS_CMD dynamodb create-table \
  --table-name reddit-analytics-local-raw-posts \
  --attribute-definitions \
    AttributeName=post_id,AttributeType=S \
    AttributeName=ingested_at,AttributeType=S \
  --key-schema \
    AttributeName=post_id,KeyType=HASH \
    AttributeName=ingested_at,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

$AWS_CMD dynamodb create-table \
  --table-name reddit-analytics-local-sentiment \
  --attribute-definitions \
    AttributeName=post_id,AttributeType=S \
    AttributeName=analyzed_at,AttributeType=S \
  --key-schema \
    AttributeName=post_id,KeyType=HASH \
    AttributeName=analyzed_at,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

$AWS_CMD dynamodb create-table \
  --table-name reddit-analytics-local-trending \
  --attribute-definitions \
    AttributeName=topic,AttributeType=S \
    AttributeName=window_ts,AttributeType=S \
  --key-schema \
    AttributeName=topic,KeyType=HASH \
    AttributeName=window_ts,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

$AWS_CMD dynamodb create-table \
  --table-name reddit-analytics-local-engagement \
  --attribute-definitions \
    AttributeName=post_id,AttributeType=S \
    AttributeName=scored_at,AttributeType=S \
  --key-schema \
    AttributeName=post_id,KeyType=HASH \
    AttributeName=scored_at,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

$AWS_CMD dynamodb create-table \
  --table-name reddit-analytics-local-authors \
  --attribute-definitions \
    AttributeName=author,AttributeType=S \
    AttributeName=profile_date,AttributeType=S \
  --key-schema \
    AttributeName=author,KeyType=HASH \
    AttributeName=profile_date,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

# --- S3 Buckets ---
echo "Creating S3 buckets..."
$AWS_CMD s3api create-bucket \
  --bucket reddit-analytics-local-raw \
  --create-bucket-configuration LocationConstraint=eu-west-2

$AWS_CMD s3api create-bucket \
  --bucket reddit-analytics-local-processed \
  --create-bucket-configuration LocationConstraint=eu-west-2

$AWS_CMD s3api create-bucket \
  --bucket reddit-analytics-local-artifacts \
  --create-bucket-configuration LocationConstraint=eu-west-2

# --- SNS Topics ---
echo "Creating SNS topics..."
$AWS_CMD sns create-topic --name reddit-analytics-local-alerts
$AWS_CMD sns create-topic --name reddit-analytics-local-trending-spikes

# --- SQS DLQs ---
echo "Creating SQS dead letter queues..."
$AWS_CMD sqs create-queue --queue-name reddit-analytics-local-sentiment-dlq
$AWS_CMD sqs create-queue --queue-name reddit-analytics-local-trending-dlq
$AWS_CMD sqs create-queue --queue-name reddit-analytics-local-engagement-dlq
$AWS_CMD sqs create-queue --queue-name reddit-analytics-local-classification-dlq
$AWS_CMD sqs create-queue --queue-name reddit-analytics-local-author-dlq

# --- Secrets Manager ---
echo "Creating Secrets Manager secret..."
$AWS_CMD secretsmanager create-secret \
  --name "reddit-analytics/api-credentials" \
  --secret-string '{
    "client_id": "local_test_client_id",
    "client_secret": "local_test_secret",
    "username": "local_test_user",
    "password": "local_test_password",
    "user_agent": "reddit-analytics-local/1.0"
  }'

echo "LocalStack setup complete!"
