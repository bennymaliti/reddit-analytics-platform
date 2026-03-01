"""
Lambda: author-profiling
Trigger: Kinesis raw-posts stream
Purpose: Build and update rolling author behavioural profiles
"""

import base64
import json
import os
import boto3
from datetime import datetime, timezone
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit
from boto3.dynamodb.conditions import Key

logger = Logger(service="author-profiling")
tracer = Tracer(service="author-profiling")
metrics = Metrics(namespace=os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "reddit-analytics"))

dynamodb = boto3.resource("dynamodb")
AUTHORS_TABLE = os.environ["DYNAMODB_AUTHORS"]
BOT_SCORE_THRESHOLD = 0.8


def decode_kinesis_record(record: dict) -> dict:
    return json.loads(base64.b64decode(record["kinesis"]["data"]).decode("utf-8"))


def calculate_bot_score(post_count: int, avg_score: float, subreddit_count: int) -> float:
    """
    Heuristic bot likelihood score (0.0 - 1.0)
    High post count + low scores + many subreddits = likely bot
    """
    high_volume = min(1.0, post_count / 100)
    low_engagement = max(0.0, 1.0 - (avg_score / 100))
    high_spread = min(1.0, subreddit_count / 20)
    return round((high_volume * 0.4 + low_engagement * 0.3 + high_spread * 0.3), 2)


@tracer.capture_lambda_handler
@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context) -> dict:
    records = event.get("Records", [])
    table = dynamodb.Table(AUTHORS_TABLE)
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    processed, errors = 0, 0

    for record in records:
        try:
            post = decode_kinesis_record(record)
            author = post.get("author_id", "")
            if not author or author == "[deleted]":
                continue

            table.update_item(
                Key={"author": author, "profile_date": today},
                UpdateExpression=(
                    "ADD post_count :one, total_score :score, total_comments :comments "
                    "SET last_active = :now, "
                    "active_subreddits = list_append(if_not_exists(active_subreddits, :empty), :sub)"
                ),
                ExpressionAttributeValues={
                    ":one": 1,
                    ":score": post.get("score", 0),
                    ":comments": post.get("num_comments", 0),
                    ":now": datetime.now(timezone.utc).isoformat(),
                    ":sub": [post.get("subreddit_id", "")],
                    ":empty": [],
                },
            )
            processed += 1
        except Exception as e:
            logger.error(f"Author profile error: {e}")
            errors += 1

    metrics.add_metric(name="AuthorsUpdated", unit=MetricUnit.Count, value=processed)
    return {"processed": processed, "errors": errors}
