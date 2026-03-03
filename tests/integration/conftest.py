import os

os.environ.setdefault("DYNAMODB_AUTHORS", "test-authors-table")
os.environ.setdefault("DYNAMODB_RAW_POSTS", "test-raw-posts-table")
os.environ.setdefault("DYNAMODB_ENGAGEMENT", "test-engagement-table")
os.environ.setdefault("DYNAMODB_SENTIMENT", "test-sentiment-table")
os.environ.setdefault("DYNAMODB_TRENDING", "test-trending-table")
os.environ.setdefault("KINESIS_RAW_STREAM", "test-raw-posts")
os.environ.setdefault("S3_RAW_BUCKET", "test-raw-bucket")
os.environ.setdefault("SNS_ALERTS_ARN", "arn:aws:sns:eu-west-2:123456789012:test-alerts")
os.environ.setdefault("SNS_TRENDING_ARN", "arn:aws:sns:eu-west-2:123456789012:test-trending")
os.environ.setdefault("REDDIT_SECRET_NAME", "test-reddit-secret")
os.environ.setdefault("REDDIT_SUBREDDITS", '["aws", "programming"]')
os.environ.setdefault("POSTS_PER_RUN", "25")
os.environ.setdefault("POWERTOOLS_METRICS_NAMESPACE", "test-namespace")
os.environ.setdefault("POWERTOOLS_SERVICE_NAME", "test-service")
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-west-2")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "testing")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "testing")
os.environ.setdefault("AWS_SECURITY_TOKEN", "testing")
os.environ.setdefault("AWS_SESSION_TOKEN", "testing")


class MockLambdaContext:
    function_name = "test-function"
    function_version = "$LATEST"
    invoked_function_arn = "arn:aws:lambda:eu-west-2:123456789012:function:test-function"
    memory_limit_in_mb = 256
    aws_request_id = "test-request-id-12345"
    log_group_name = "/aws/lambda/test-function"
    log_stream_name = "2026/01/01/[$LATEST]test"
    remaining_time_in_millis = 30000
