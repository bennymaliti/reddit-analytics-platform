"""
Lambda: sentiment-analysis
Trigger: Kinesis raw-posts stream
Purpose: Run NLP sentiment analysis via Amazon Comprehend
"""

import base64
import json
import os
import boto3
from datetime import datetime, timezone
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="sentiment-analysis")
tracer = Tracer(service="sentiment-analysis")
metrics = Metrics(namespace=os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "reddit-analytics"))

comprehend = boto3.client("comprehend")
dynamodb = boto3.resource("dynamodb")

SENTIMENT_TABLE = os.environ["DYNAMODB_SENTIMENT"]
MAX_BATCH_SIZE = 25


def decode_kinesis_record(record: dict) -> dict:
    return json.loads(base64.b64decode(record["kinesis"]["data"]).decode("utf-8"))


def analyse_sentiment_batch(texts: list) -> list:
    results = []
    for i in range(0, len(texts), MAX_BATCH_SIZE):
        batch = texts[i:i + MAX_BATCH_SIZE]
        response = comprehend.batch_detect_sentiment(
            TextList=[t[:4900] for t in batch], LanguageCode="en"
        )
        results.extend(response["ResultList"])
    return results


@tracer.capture_lambda_handler
@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context) -> dict:
    records = event.get("Records", [])
    table = dynamodb.Table(SENTIMENT_TABLE)
    posts = [decode_kinesis_record(r) for r in records]

    texts = [f"{p.get('title', '')} {p.get('body', '')}".strip() for p in posts]
    sentiment_results = analyse_sentiment_batch(texts)

    processed, errors = 0, 0
    with table.batch_writer() as batch:
        for post, sentiment in zip(posts, sentiment_results):
            try:
                scores = sentiment.get("SentimentScore", {})
                batch.put_item(
                    Item={
                        "post_id": post["post_id"],
                        "analyzed_at": datetime.now(timezone.utc).isoformat(),
                        "sentiment": sentiment.get("Sentiment", "NEUTRAL"),
                        "positive_score": str(round(scores.get("Positive", 0), 4)),
                        "negative_score": str(round(scores.get("Negative", 0), 4)),
                        "neutral_score": str(round(scores.get("Neutral", 0), 4)),
                        "mixed_score": str(round(scores.get("Mixed", 0), 4)),
                        "subreddit": post.get("subreddit_id", ""),
                        "title": post.get("title", "")[:500],
                    }
                )
                processed += 1
            except Exception as e:
                logger.error(f"Error storing sentiment for {post.get('post_id')}: {e}")
                errors += 1

    metrics.add_metric(name="SentimentProcessed", unit=MetricUnit.Count, value=processed)
    logger.info(f"Sentiment complete: {processed} processed, {errors} errors")
    return {"processed": processed, "errors": errors}
