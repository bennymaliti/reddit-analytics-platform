class MockLambdaContext:
    function_name = "test-function"
    function_version = "$LATEST"
    invoked_function_arn = "arn:aws:lambda:eu-west-2:123456789012:function:test-function"
    memory_limit_in_mb = 256
    aws_request_id = "test-request-id-12345"
    log_group_name = "/aws/lambda/test-function"
    log_stream_name = "2026/01/01/[$LATEST]test"
    remaining_time_in_millis = 30000
