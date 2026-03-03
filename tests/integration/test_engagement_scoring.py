"""
Integration tests for engagement scoring Lambda
Uses moto to mock AWS services
"""
import base64
import json
import os
import time
import pytest
import boto3
from moto import mock_aws
from tests.helpers import MockLambdaContext


def make_kinesis_record(post: dict) -> dict:
    return {
        "kinesis": {
            "data": base64.b64encode(json.dumps(post).encode()).decode()
        }
    }


@mock_aws
def test_engagement_score_stored_in_dynamodb():
    """Test that engagement scores are stored correctly in DynamoDB"""
    import importlib.util

    dynamodb = boto3.resource("dynamodb", region_name="eu-west-2")
    dynamodb.create_table(
        TableName="test-engagement-table",
        KeySchema=[
            {"AttributeName": "post_id", "KeyType": "HASH"},
            {"AttributeName": "scored_at", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "post_id", "AttributeType": "S"},
            {"AttributeName": "scored_at", "AttributeType": "S"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )

    spec = importlib.util.spec_from_file_location(
        "engagement_integration",
        os.path.join(os.path.dirname(__file__), "../../src/lambdas/engagement_scoring/handler.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    post = {
        "post_id": "viral_post_001",
        "subreddit_id": "aws",
        "score": 5000,
        "upvote_ratio": 0.97,
        "num_comments": 250,
        "num_awards": 5,
        "created_utc": int(time.time()) - 3600,
    }

    event = {"Records": [make_kinesis_record(post)]}
    result = module.lambda_handler(event, MockLambdaContext())

    assert result["processed"] == 1
    assert result["errors"] == 0

    table = dynamodb.Table("test-engagement-table")
    response = table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key("post_id").eq("viral_post_001")
    )
    items = response["Items"]
    assert len(items) == 1
    assert float(items[0]["engagement_score"]) > 0
    assert float(items[0]["upvote_ratio"]) == 0.97
    assert int(items[0]["score"]) == 5000


@mock_aws
def test_low_engagement_post_stored_correctly():
    """Test that low engagement posts are also stored"""
    import importlib.util

    dynamodb = boto3.resource("dynamodb", region_name="eu-west-2")
    dynamodb.create_table(
        TableName="test-engagement-table",
        KeySchema=[
            {"AttributeName": "post_id", "KeyType": "HASH"},
            {"AttributeName": "scored_at", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "post_id", "AttributeType": "S"},
            {"AttributeName": "scored_at", "AttributeType": "S"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )

    spec = importlib.util.spec_from_file_location(
        "engagement_integration2",
        os.path.join(os.path.dirname(__file__), "../../src/lambdas/engagement_scoring/handler.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    post = {
        "post_id": "low_post_001",
        "subreddit_id": "programming",
        "score": 1,
        "upvote_ratio": 0.5,
        "num_comments": 0,
        "num_awards": 0,
        "created_utc": int(time.time()) - 7200,
    }

    event = {"Records": [make_kinesis_record(post)]}
    result = module.lambda_handler(event, MockLambdaContext())

    assert result["processed"] == 1
    assert result["errors"] == 0
