"""
Lambda: trending-topics
Trigger: Kinesis raw-posts stream
Purpose: Detect trending topics using rolling time windows
"""
import base64
import json
import os
import time
import boto3
from datetime import datetime, timezone
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="trending-topics")
tracer = Tracer(service="trending-topics")
metrics = Metrics(namespace=os.environ.get("POWERTOOLS_METRICS_NAMESPACE", "reddit-analytics"))

comprehend = boto3.client("comprehend")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

TRENDING_TABLE = os.environ["DYNAMODB_TRENDING"]
SNS_TRENDING_ARN = os.environ["SNS_TRENDING_ARN"]
VIRAL_THRESHOLD = 50
WINDOWS = ["1h", "24h", "7d"]


def decode_kinesis_record(record: dict) -> dict:
    return json.loads(base64.b64decode(record["kinesis"]["data"]).decode("utf-8"))


def extract_key_phrases(texts: list) -> list:
    all_phrases = []
    for i in range(0, len(texts), 25):
        batch = texts[i:i + 25]
        try:
            response = comprehend.batch_detect_key_phrases(
                TextList=[t[:4900] for t in batch],
                LanguageCode="en"
            )
            for result in response["ResultList"]:
                phrases = [kp["Text"].lower() for kp in result.get("KeyPhrases", [])
                           if kp["Score"] > 0.9 and len(kp["Text"]) > 3]
                all_phrases.extend(phrases)
        except Exception as e:
            logger.error(f"Comprehend key phrase error: {e}")
    return all_phrases


def get_ttl(window: str) -> int:
    ttl_map = {"1h": 3600, "24h": 86400, "7d": 604800}
    return int(time.time()) + ttl_map.get(window, 86400)


@tracer.capture_lambda_handler
@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context) -> dict:
    records = event.get("Records", [])
    posts = [decode_kinesis_record(r) for r in records]
    table = dynamodb.Table(TRENDING_TABLE)

    texts = [f"{p.get('title', '')} {p.get('body', '')}".strip() for p in posts]
    phrases = extract_key_phrases(texts)

    phrase_counts: dict = {}
    for phrase in phrases:
        phrase_counts[phrase] = phrase_counts.get(phrase, 0) + 1

    now = datetime.now(timezone.utc)
    updated = 0

    for topic, count in phrase_counts.items():
        for window in WINDOWS:
            try:
                table.update_item(
                    Key={"topic": topic, "window_ts": f"{window}#{now.isoformat()}"},
                    UpdateExpression="ADD mention_count :c SET #w = :w, last_seen = :ls, #ttl = :ttl",
                    ExpressionAttributeNames={"#w": "window", "#ttl": "ttl"},
                    ExpressionAttributeValues={
                        ":c": count,
                        ":w": window,
                        ":ls": now.isoformat(),
                        ":ttl": get_ttl(window),
                    }
                )
                updated += 1
            except Exception as e:
                logger.error(f"Error updating trending for {topic}: {e}")

        if count >= VIRAL_THRESHOLD:
            try:
                sns.publish(
                    TopicArn=SNS_TRENDING_ARN,
                    Subject=f"Trending spike: {topic}",
                    Message=json.dumps({"topic": topic, "count": count,
                                        "timestamp": now.isoformat()}),
                )
            except Exception as e:
                logger.error(f"SNS publish error: {e}")

    metrics.add_metric(name="TopicsUpdated", unit=MetricUnit.Count, value=updated)
    logger.info(f"Trending update complete: {updated} topic-window pairs updated")
    return {"topics_found": len(phrase_counts), "updates": updated}
