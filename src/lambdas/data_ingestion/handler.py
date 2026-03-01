"""
Lambda: data-ingestion
Trigger: EventBridge schedule (every 5 minutes)
Purpose: Poll Reddit PRAW API and publish raw posts to Kinesis Data Stream
"""

import json
import os
import time
import boto3
import praw
from datetime import datetime, timezone
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="data-ingestion")
tracer = Tracer(service="data-ingestion")
metrics = Metrics(namespace=os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "reddit-analytics"))

secretsmanager = boto3.client("secretsmanager")
kinesis = boto3.client("kinesis")
s3 = boto3.client("s3")

RAW_POSTS_STREAM = os.environ["KINESIS_RAW_STREAM"]
TARGET_SUBREDDITS = os.environ.get("REDDIT_SUBREDDITS", "aws,programming").split(",")
REDDIT_SECRET_NAME = os.environ["REDDIT_SECRET_NAME"]
POST_LIMIT = int(os.environ.get("POSTS_PER_RUN", "25"))
S3_RAW_BUCKET = os.environ["S3_RAW_BUCKET"]


@tracer.capture_method
def get_reddit_client():
    secret = secretsmanager.get_secret_value(SecretId=REDDIT_SECRET_NAME)
    creds = json.loads(secret["SecretString"])
    return praw.Reddit(
        client_id=creds["client_id"],
        client_secret=creds["client_secret"],
        username=creds["username"],
        password=creds["password"],
        user_agent=creds.get("user_agent", "reddit-analytics/1.0"),
    )


def normalise_post(post, subreddit: str) -> dict:
    return {
        "event_type": "reddit_post",
        "schema_version": "1.0",
        "post_id": post.id,
        "subreddit_id": subreddit.lower(),
        "subreddit_display": subreddit,
        "title": post.title,
        "body": post.selftext[:2000] if post.selftext else "",
        "url": post.url,
        "permalink": f"https://reddit.com{post.permalink}",
        "author_id": str(post.author) if post.author else "[deleted]",
        "score": post.score,
        "upvote_ratio": post.upvote_ratio,
        "num_comments": post.num_comments,
        "num_awards": post.total_awards_received,
        "is_nsfw": post.over_18,
        "flair": post.link_flair_text or "",
        "created_utc": int(post.created_utc),
        "ingested_at": datetime.now(timezone.utc).isoformat(),
        "ingested_epoch": int(time.time()),
        "ttl": int(time.time()) + (30 * 86400),
    }


@tracer.capture_method
def batch_put_kinesis(records: list, stream_name: str) -> dict:
    total_sent, total_failed = 0, 0
    for i in range(0, len(records), 500):
        batch = records[i : i + 500]
        kinesis_records = [
            {"Data": json.dumps(r).encode("utf-8"), "PartitionKey": r["subreddit_id"]}
            for r in batch
        ]
        response = kinesis.put_records(Records=kinesis_records, StreamName=stream_name)
        total_sent += len(batch) - response["FailedRecordCount"]
        total_failed += response["FailedRecordCount"]
    return {"sent": total_sent, "failed": total_failed}


def archive_to_s3(posts: list, subreddit: str) -> None:
    import gzip

    now = datetime.now(timezone.utc)
    key = (
        f"raw/subreddit={subreddit}/year={now.year}/month={now.month:02d}/"
        f"day={now.day:02d}/hour={now.hour:02d}/{now.strftime('%Y%m%dT%H%M%S')}.json.gz"
    )
    body = gzip.compress(json.dumps(posts, default=str).encode())
    s3.put_object(Bucket=S3_RAW_BUCKET, Key=key, Body=body, ContentEncoding="gzip")


@tracer.capture_lambda_handler
@logger.inject_lambda_context(log_event=True)
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context) -> dict:
    reddit = get_reddit_client()
    all_records = []
    subreddit_counts = {}

    for subreddit_name in TARGET_SUBREDDITS:
        subreddit_name = subreddit_name.strip()
        try:
            posts = [
                normalise_post(p, subreddit_name)
                for p in reddit.subreddit(subreddit_name).new(limit=POST_LIMIT)
            ]
            archive_to_s3(posts, subreddit_name)
            all_records.extend(posts)
            subreddit_counts[subreddit_name] = len(posts)
            logger.info(f"Fetched {len(posts)} posts from r/{subreddit_name}")
        except Exception as e:
            logger.error(f"Failed r/{subreddit_name}: {e}")
            metrics.add_metric(name="IngestionError", unit=MetricUnit.Count, value=1)

    if all_records:
        result = batch_put_kinesis(all_records, RAW_POSTS_STREAM)
        metrics.add_metric(name="PostsIngested", unit=MetricUnit.Count, value=result["sent"])
        logger.info("Published to Kinesis %s", result)

    return {
        "statusCode": 200,
        "subreddits_processed": subreddit_counts,
        "total_published": len(all_records),
    }
