"""
Lambda: engagement-scoring
Trigger: Kinesis raw-posts stream
Purpose: Calculate composite engagement score for each post
"""

import base64
import json
import os
import math
import boto3
from decimal import Decimal
from datetime import datetime, timezone
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="engagement-scoring")
tracer = Tracer(service="engagement-scoring")
metrics = Metrics(namespace=os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "reddit-analytics"))
dynamodb = boto3.resource("dynamodb")
ENGAGEMENT_TABLE = os.environ["DYNAMODB_ENGAGEMENT"]


def decode_kinesis_record(record: dict) -> dict:
    return json.loads(base64.b64decode(record["kinesis"]["data"]).decode("utf-8"))


def calculate_engagement_score(post: dict) -> float:
    score = post.get("score", 0)
    upvote_ratio = post.get("upvote_ratio", 0.5)
    num_comments = post.get("num_comments", 0)
    num_awards = post.get("num_awards", 0)
    weighted_score = score * upvote_ratio
    comment_factor = math.log1p(num_comments) * 10
    award_bonus = num_awards * 5
    raw_score = weighted_score + comment_factor + award_bonus
    normalized = min(100, (raw_score / 1000) * 100)
    return round(normalized, 2)


def calculate_comment_velocity(post: dict) -> float:
    created_utc = post.get("created_utc", 0)
    num_comments = post.get("num_comments", 0)
    if not created_utc:
        return 0.0
    age_hours = max(0.1, (datetime.now(timezone.utc).timestamp() - created_utc) / 3600)
    return round(num_comments / age_hours, 2)


@tracer.capture_lambda_handler
@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context) -> dict:
    records = event.get("Records", [])
    table = dynamodb.Table(ENGAGEMENT_TABLE)
    processed, errors = 0, 0

    with table.batch_writer() as batch:
        for record in records:
            try:
                post = decode_kinesis_record(record)
                engagement_score = calculate_engagement_score(post)
                comment_velocity = calculate_comment_velocity(post)
                batch.put_item(
                    Item={
                        "post_id": post["post_id"],
                        "scored_at": datetime.now(timezone.utc).isoformat(),
                        "engagement_score": Decimal(str(engagement_score)),
                        "upvote_ratio": Decimal(str(post.get("upvote_ratio", 0))),
                        "score": int(post.get("score", 0)),
                        "num_comments": int(post.get("num_comments", 0)),
                        "num_awards": int(post.get("num_awards", 0)),
                        "comment_velocity": Decimal(str(comment_velocity)),
                        "subreddit": post.get("subreddit_id", ""),
                    }
                )
                processed += 1
            except Exception as e:
                logger.error(f"Error scoring post: {e}")
                errors += 1

    metrics.add_metric(name="PostsScored", unit=MetricUnit.Count, value=processed)
    logger.info(f"Engagement scoring complete: {processed} scored, {errors} errors")
    return {"processed": processed, "errors": errors}
