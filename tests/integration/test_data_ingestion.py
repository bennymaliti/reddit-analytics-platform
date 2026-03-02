"""
Integration tests for data ingestion Lambda
Uses moto to mock AWS services
"""
import json
import os
import pytest
import boto3
from moto import mock_aws
from unittest.mock import patch, MagicMock

# -----------------------------------------------
# Fixtures
# -----------------------------------------------

@pytest.fixture
def aws_credentials():
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "eu-west-2"


@pytest.fixture
def kinesis_stream(aws_credentials):
    with mock_aws():
        client = boto3.client("kinesis", region_name="eu-west-2")
        client.create_stream(StreamName="test-raw-posts", ShardCount=1)
        yield client


@pytest.fixture
def s3_bucket(aws_credentials):
    with mock_aws():
        client = boto3.client("s3", region_name="eu-west-2")
        client.create_bucket(
            Bucket="test-raw-bucket",
            CreateBucketConfiguration={"LocationConstraint": "eu-west-2"},
        )
        yield client


@pytest.fixture
def secrets_manager(aws_credentials):
    with mock_aws():
        client = boto3.client("secretsmanager", region_name="eu-west-2")
        client.create_secret(
            Name="test-reddit-secret",
            SecretString=json.dumps({
                "client_id": "test_client_id",
                "client_secret": "test_client_secret",
                "username": "test_user",
                "password": "test_password",
                "user_agent": "test-agent/1.0",
            }),
        )
        yield client


# -----------------------------------------------
# Tests
# -----------------------------------------------

@mock_aws
def test_normalise_post_structure(aws_credentials):
    """Test that normalise_post returns all required fields"""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "ingestion_handler",
        os.path.join(os.path.dirname(__file__), "../../src/lambdas/data_ingestion/handler.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    mock_post = MagicMock()
    mock_post.id = "abc123"
    mock_post.title = "Test Post Title"
    mock_post.selftext = "Test body content"
    mock_post.url = "https://reddit.com/r/test/abc123"
    mock_post.permalink = "/r/test/abc123"
    mock_post.author = MagicMock(__str__=lambda self: "testuser")
    mock_post.score = 100
    mock_post.upvote_ratio = 0.95
    mock_post.num_comments = 25
    mock_post.total_awards_received = 2
    mock_post.over_18 = False
    mock_post.link_flair_text = "Discussion"
    mock_post.created_utc = 1700000000.0

    result = module.normalise_post(mock_post, "aws")

    assert result["post_id"] == "abc123"
    assert result["title"] == "Test Post Title"
    assert result["subreddit_id"] == "aws"
    assert result["author_id"] == "testuser"
    assert result["score"] == 100
    assert result["upvote_ratio"] == 0.95
    assert result["num_comments"] == 25
    assert result["num_awards"] == 2
    assert result["is_nsfw"] is False
    assert result["event_type"] == "reddit_post"
    assert result["schema_version"] == "1.0"
    assert "ingested_at" in result
    assert "ttl" in result


@mock_aws
def test_batch_put_kinesis(aws_credentials):
    """Test that records are successfully published to Kinesis"""
    import importlib.util

    boto3.client("kinesis", region_name="eu-west-2").create_stream(
        StreamName="test-raw-posts", ShardCount=1
    )

    spec = importlib.util.spec_from_file_location(
        "ingestion_handler",
        os.path.join(os.path.dirname(__file__), "../../src/lambdas/data_ingestion/handler.py"),
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    records = [
        {
            "post_id": f"post_{i}",
            "subreddit_id": "aws",
            "title": f"Test Post {i}",
            "score": i * 10,
        }
        for i in range(5)
    ]

    result = module.batch_put_kinesis(records, "test-raw-posts")

    assert result["sent"] == 5
    assert result["failed"] == 0
