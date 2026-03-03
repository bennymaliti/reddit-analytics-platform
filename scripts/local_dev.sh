#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="http://localhost:4566"
AWS_LOCAL="aws --endpoint-url=$ENDPOINT --region eu-west-2"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=eu-west-2

export KINESIS_RAW_STREAM=reddit-analytics-local-raw-posts
export S3_RAW_BUCKET=reddit-analytics-local-raw
export DYNAMODB_RAW_POSTS=reddit-analytics-local-raw-posts
export DYNAMODB_SENTIMENT=reddit-analytics-local-sentiment
export DYNAMODB_TRENDING=reddit-analytics-local-trending
export DYNAMODB_ENGAGEMENT=reddit-analytics-local-engagement
export DYNAMODB_AUTHORS=reddit-analytics-local-authors
export SNS_ALERTS_ARN=arn:aws:sns:eu-west-2:000000000000:reddit-analytics-local-alerts
export SNS_TRENDING_ARN=arn:aws:sns:eu-west-2:000000000000:reddit-analytics-local-trending-spikes
export REDDIT_SECRET_NAME=reddit-analytics/api-credentials
export REDDIT_SUBREDDITS='["aws","programming"]'
export POSTS_PER_RUN=5
export POWERTOOLS_METRICS_NAMESPACE=reddit-analytics-local
export POWERTOOLS_SERVICE_NAME=local-dev

case "${1:-help}" in
  start)
    echo "Starting LocalStack..."
    docker-compose up -d localstack
    echo "Waiting for LocalStack to be ready..."
    sleep 10
    bash scripts/localstack/01_setup.sh
    echo "Local environment ready at $ENDPOINT"
    ;;
  stop)
    echo "Stopping LocalStack..."
    docker-compose down
    ;;
  status)
    echo "=== Kinesis Streams ==="
    $AWS_LOCAL kinesis list-streams
    echo "=== DynamoDB Tables ==="
    $AWS_LOCAL dynamodb list-tables
    echo "=== S3 Buckets ==="
    $AWS_LOCAL s3 ls
    ;;
  invoke)
    FUNCTION=${2:-data_ingestion}
    echo "Invoking $FUNCTION locally..."
    python -c "
import sys
sys.path.insert(0, 'src/lambdas/$FUNCTION')
import importlib.util, json
spec = importlib.util.spec_from_file_location('handler', 'src/lambdas/$FUNCTION/handler.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
result = mod.lambda_handler({}, type('ctx', (), {
    'function_name': 'local-$FUNCTION',
    'function_version': 'local',
    'invoked_function_arn': 'arn:aws:lambda:eu-west-2:000000000000:function:local-$FUNCTION',
    'memory_limit_in_mb': 256,
    'aws_request_id': 'local-request-001',
    'log_group_name': '/aws/lambda/local-$FUNCTION',
    'log_stream_name': 'local',
    'remaining_time_in_millis': 30000,
})())
print(json.dumps(result, indent=2))
"
    ;;
  scan)
    TABLE=${2:-reddit-analytics-local-raw-posts}
    echo "Scanning table: $TABLE"
    $AWS_LOCAL dynamodb scan --table-name "$TABLE" --max-items 5
    ;;
  help|*)
    echo "Usage: ./scripts/local_dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start           Start LocalStack and create all resources"
    echo "  stop            Stop LocalStack"
    echo "  status          Show all local AWS resources"
    echo "  invoke [fn]     Invoke a Lambda function locally"
    echo "  scan [table]    Scan a DynamoDB table"
    ;;
esac
