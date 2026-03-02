"""
Integration tests for sentiment analysis Lambda
Uses moto to mock AWS services
"""
import base64
import json
import os
import pytest
import boto3
from moto import mock_aws
from unittest.mock import patch, MagicMock


@pytest.fixture(autouse=True)
def aws_credentials():
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "eu-west-2"


def make_kinesis_record(post: dict) -> dict:
    """Helper to create a mock Kinesis record"""
    return {
        "kinesis": {
            "data": base64.b64encode(json.dumps(post).encode()).decode()
        }
    }


@mock_aws
def test_sentiment_stored_in_dynamodb():
    """Test that sentiment results are stored correctly in DynamoDB"""
    import importlib.util

    dynamodb = boto3.resource("dynamodb", region_name="eu-west-2")
    dynamodb.create_table(
        TableName="test-sentiment-table",
        KeySchema=[
            {"AttributeName": "post_id", "KeyType": "HASH"},
            {"AttributeName": "analyzed_at", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "post_id", "AttributeType": "S"},
            {"AttributeName": "analyzed_at", "AttributeType": "S"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )

    spec = importlib.util.spec_from_file_location(
        "sentiment_handler",
        os.path.join(os.path.dirname(__file__), "../../src/lambdas/sentiment_analysis/handler.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    post = {
        "post_id": "test_post_001",
        "title": "AWS Lambda is amazing for serverless computing",
        "body": "I really enjoy using AWS services for cloud architecture",
        "subreddit_id": "aws",
    }

    mock_sentiment = {
        "Sentiment": "POSITIVE",
        "SentimentScore": {
            "Positive": 0.95,
            "Negative": 0.02,
            "Neutral": 0.02,
            "Mixed": 0.01,
        },
    }

    event = {"Records": [make_kinesis_record(post)]}

    with patch.object(module, "comprehend") as mock_comprehend:
        mock_comprehend.batch_detect_sentiment.return_value = {
            "ResultList": [mock_sentiment],
            "ErrorList": [],
        }

        result = module.lambda_handler(event, {})

    assert result["processed"] == 1
    assert result["errors"] == 0

    table = dynamodb.Table("test-sentiment-table")
    response = table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key("post_id").eq("test_post_001")
    )
    items = response["Items"]
    assert len(items) == 1
    assert items[0]["sentiment"] == "POSITIVE"
    assert float(items[0]["positive_score"]) > 0.9


@mock_aws
def test_sentiment_handles_multiple_records():
    """Test batch processing of multiple Kinesis records"""
    import importlib.util

    dynamodb = boto3.resource("dynamodb", region_name="eu-west-2")
    dynamodb.create_table(
        TableName="test-sentiment-table",
        KeySchema=[
            {"AttributeName": "post_id", "KeyType": "HASH"},
            {"AttributeName": "analyzed_at", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "post_id", "AttributeType": "S"},
            {"AttributeName": "analyzed_at", "AttributeType": "S"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )

    spec = importlib.util.spec_from_file_location(
        "sentiment_handler2",
        os.path.join(os.path.dirname(__file__), "../../src/lambdas/sentiment_analysis/handler.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    posts = [
        {"post_id": f"post_{i}", "title": f"Test post {i}", "body": "", "subreddit_id": "aws"}
        for i in range(3)
    ]

    mock_results = [
        {
            "Sentiment": "NEUTRAL",
            "SentimentScore": {
                "Positive": 0.1, "Negative": 0.1, "Neutral": 0.75, "Mixed": 0.05
            },
        }
        for _ in range(3)
    ]

    event = {"Records": [make_kinesis_record(p) for p in posts]}

    with patch.object(module, "comprehend") as mock_comprehend:
        mock_comprehend.batch_detect_sentiment.return_value = {
            "ResultList": mock_results,
            "ErrorList": [],
        }
        result = module.lambda_handler(event, {})

    assert result["processed"] == 3
    assert result["errors"] == 0
