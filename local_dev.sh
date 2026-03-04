#!/bin/bash
# local_dev.sh - Helper script for LocalStack development

AWS_LOCAL="aws --endpoint-url=http://localhost:4566 --region eu-west-2"

case "$1" in
  start)
    echo "íº€ Starting LocalStack..."
    docker-compose up -d localstack
    echo "â³ Waiting for LocalStack to be ready..."
    sleep 10
    echo "âœ… LocalStack running at http://localhost:4566"
    ;;

  stop)
    echo "í»‘ Stopping LocalStack..."
    docker-compose down
    echo "âœ… LocalStack stopped"
    ;;

  status)
    echo "=== LocalStack Status ==="
    curl -s http://localhost:4566/_localstack/health | python3 -m json.tool
    ;;

  invoke)
    FUNCTION=${2:-data_ingestion}
    PAYLOAD=${3:-'{"mock": true}'}
    echo "âš¡ Invoking $FUNCTION..."
    $AWS_LOCAL lambda invoke \
      --function-name reddit-analytics-local-${FUNCTION} \
      --cli-binary-format raw-in-base64-out \
      --payload "$PAYLOAD" \
      /tmp/response.json && cat /tmp/response.json
    ;;

  scan)
    TABLE=${2:-raw-posts}
    echo "í³Š Scanning reddit-analytics-local-${TABLE}..."
    $AWS_LOCAL dynamodb scan \
      --table-name reddit-analytics-local-${TABLE} \
      --max-items 5 \
      --output json | python3 -m json.tool
    ;;

  logs)
    FUNCTION=${2:-data_ingestion}
    echo "í³‹ Logs for $FUNCTION..."
    $AWS_LOCAL logs filter-log-events \
      --log-group-name /aws/lambda/reddit-analytics-local-${FUNCTION} \
      --query "events[*].message" \
      --output text 2>&1 | tail -30
    ;;

  tables)
    echo "í³‹ DynamoDB tables:"
    $AWS_LOCAL dynamodb list-tables --output table
    ;;

  streams)
    echo "í³¡ Kinesis streams:"
    $AWS_LOCAL kinesis list-streams --output table
    ;;

  buckets)
    echo "íº£ S3 buckets:"
    $AWS_LOCAL s3 ls
    ;;

  reset)
    echo "í´„ Resetting LocalStack data..."
    docker-compose down -v
    docker-compose up -d localstack
    echo "âœ… LocalStack reset complete"
    ;;

  *)
    echo "Reddit Analytics Platform â€” Local Development Helper"
    echo ""
    echo "Usage: ./local_dev.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start              Start LocalStack"
    echo "  stop               Stop LocalStack"
    echo "  status             Check LocalStack health"
    echo "  invoke <function>  Invoke a Lambda function (default: data_ingestion)"
    echo "  scan <table>       Scan a DynamoDB table (default: raw-posts)"
    echo "  logs <function>    View Lambda logs"
    echo "  tables             List all DynamoDB tables"
    echo "  streams            List all Kinesis streams"
    echo "  buckets            List all S3 buckets"
    echo "  reset              Wipe and restart LocalStack"
    echo ""
    echo "Examples:"
    echo "  ./local_dev.sh start"
    echo "  ./local_dev.sh invoke data_ingestion '{\"mock\": true}'"
    echo "  ./local_dev.sh scan sentiment"
    echo "  ./local_dev.sh logs sentiment_analysis"
    ;;
esac
