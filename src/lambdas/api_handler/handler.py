"""
Lambda: api-handler
Trigger: API Gateway REST
Purpose: Unified query layer for all analytics data
"""

import json
import os
import boto3
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Key, Attr
from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.event_handler import APIGatewayRestResolver
from aws_lambda_powertools.logging import correlation_paths

logger = Logger(service="api-handler")
tracer = Tracer(service="api-handler")
app = APIGatewayRestResolver()

dynamodb = boto3.resource("dynamodb")

TABLES = {
    "raw_posts": os.environ["DYNAMODB_RAW_POSTS"],
    "sentiment": os.environ["DYNAMODB_SENTIMENT"],
    "trending": os.environ["DYNAMODB_TRENDING"],
    "engagement": os.environ["DYNAMODB_ENGAGEMENT"],
    "authors": os.environ["DYNAMODB_AUTHORS"],
}


def response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }


@app.get("/trending")
def get_trending():
    window = app.current_event.get_query_string_value("window", "24h")
    limit = int(app.current_event.get_query_string_value("limit", "20"))
    table = dynamodb.Table(TABLES["trending"])

    result = table.query(
        IndexName="by-count-index",
        KeyConditionExpression=Key("window").eq(window),
        ScanIndexForward=False,
        Limit=min(limit, 100),
    )

    return response(
        200,
        {
            "window": window,
            "topics": result.get("Items", []),
            "count": result.get("Count", 0),
            "generated_at": datetime.now(timezone.utc).isoformat(),
        },
    )


@app.get("/sentiment/<post_id>")
def get_sentiment(post_id: str):
    table = dynamodb.Table(TABLES["sentiment"])
    result = table.query(
        KeyConditionExpression=Key("post_id").eq(post_id),
        ScanIndexForward=False,
        Limit=1,
    )
    items = result.get("Items", [])
    if not items:
        return response(404, {"error": f"No sentiment data found for post {post_id}"})
    return response(200, items[0])


@app.get("/engagement")
def get_engagement():
    subreddit = app.current_event.get_query_string_value("subreddit", None)
    limit = int(app.current_event.get_query_string_value("limit", "20"))
    table = dynamodb.Table(TABLES["engagement"])

    if subreddit:
        result = table.query(
            IndexName="by-score-index",
            KeyConditionExpression=Key("subreddit").eq(subreddit),
            ScanIndexForward=False,
            Limit=min(limit, 100),
        )
    else:
        result = table.scan(Limit=min(limit, 100))

    return response(
        200,
        {
            "posts": result.get("Items", []),
            "count": result.get("Count", 0),
        },
    )


@app.get("/authors/<username>")
def get_author(username: str):
    table = dynamodb.Table(TABLES["authors"])
    result = table.query(
        KeyConditionExpression=Key("author").eq(username),
        ScanIndexForward=False,
        Limit=30,
    )
    items = result.get("Items", [])
    if not items:
        return response(404, {"error": f"No profile found for author {username}"})
    return response(200, {"author": username, "history": items})


@app.post("/search")
def search_posts():
    body = app.current_event.json_body or {}
    query = body.get("query", "")
    limit = int(body.get("limit", 20))
    table = dynamodb.Table(TABLES["raw_posts"])

    result = table.scan(
        FilterExpression=Attr("title").contains(query),
        Limit=min(limit, 100),
    )
    return response(
        200,
        {
            "query": query,
            "results": result.get("Items", []),
            "count": result.get("Count", 0),
        },
    )


@logger.inject_lambda_context(correlation_id_path=correlation_paths.API_GATEWAY_REST)
@tracer.capture_lambda_handler
def lambda_handler(event: dict, context) -> dict:
    return app.resolve(event, context)
