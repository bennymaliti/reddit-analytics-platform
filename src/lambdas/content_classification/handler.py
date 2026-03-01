"""
Lambda: content-classification
Trigger: Kinesis raw-posts stream
Purpose: Classify posts by content type and topic category
"""
import base64
import json
import os
import boto3
from datetime import datetime, timezone
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="content-classification")
tracer = Tracer(service="content-classification")
metrics = Metrics(namespace=os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "reddit-analytics"))

comprehend = boto3.client("comprehend")
dynamodb = boto3.resource("dynamodb")
RAW_POSTS_TABLE = os.environ["DYNAMODB_RAW_POSTS"]

TOPIC_KEYWORDS = {
    "technology": ["ai", "machine learning", "software", "hardware", "cloud", "aws", "python"],
    "finance":    ["stock", "market", "investment", "crypto", "bitcoin", "economy"],
    "science":    ["research", "study", "discovery", "climate", "space", "biology"],
    "politics":   ["government", "election", "policy", "senate", "president"],
    "gaming":     ["game", "gaming", "xbox", "playstation", "nintendo", "steam"],
}


def decode_kinesis_record(record: dict) -> dict:
    return json.loads(base64.b64decode(record["kinesis"]["data"]).decode("utf-8"))


def classify_post_type(post: dict) -> str:
    url = post.get("url", "")
    if post.get("body"):
        return "text"
    if any(ext in url for ext in [".jpg", ".jpeg", ".png", ".gif", ".webp"]):
        return "image"
    if any(domain in url for domain in ["youtube.com", "youtu.be", "vimeo.com"]):
        return "video"
    return "link"


def classify_topic(title: str, body: str) -> str:
    text = f"{title} {body}".lower()
    scores = {topic: sum(1 for kw in keywords if kw in text)
              for topic, keywords in TOPIC_KEYWORDS.items()}
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "general"


def detect_entities(text: str) -> list:
    try:
        response = comprehend.detect_entities(Text=text[:4900], LanguageCode="en")
        return [e["Text"] for e in response["Entities"] if e["Score"] > 0.9][:10]
    except Exception:
        return []


@tracer.capture_lambda_handler
@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context) -> dict:
    records = event.get("Records", [])
    table = dynamodb.Table(RAW_POSTS_TABLE)
    processed, errors = 0, 0

    for record in records:
        try:
            post = decode_kinesis_record(record)
            title = post.get("title", "")
            body = post.get("body", "")

            post_type = classify_post_type(post)
            topic = classify_topic(title, body)
            entities = detect_entities(f"{title} {body}"[:4900])

            table.update_item(
                Key={"post_id": post["post_id"], "ingested_at": post["ingested_at"]},
                UpdateExpression="SET post_type = :pt, topic_category = :tc, "
                                 "entities = :e, classified_at = :ca",
                ExpressionAttributeValues={
                    ":pt": post_type,
                    ":tc": topic,
                    ":e":  entities,
                    ":ca": datetime.now(timezone.utc).isoformat(),
                }
            )
            processed += 1
        except Exception as e:
            logger.error(f"Classification error: {e}")
            errors += 1

    metrics.add_metric(name="PostsClassified", unit=MetricUnit.Count, value=processed)
    return {"processed": processed, "errors": errors}
