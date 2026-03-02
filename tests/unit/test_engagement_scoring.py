"""Unit tests for engagement scoring Lambda"""
import pytest
import sys
import os
os.environ.setdefault("AWS_REGION", "eu-west-2")
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-west-2")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../src/lambdas/engagement_scoring"))

from handler import calculate_engagement_score, calculate_comment_velocity


def test_engagement_score_zero_for_empty_post():
    post = {"score": 0, "upvote_ratio": 0.0, "num_comments": 0, "num_awards": 0}
    assert calculate_engagement_score(post) == 0.0


def test_engagement_score_high_for_viral_post():
    post = {"score": 10000, "upvote_ratio": 0.98, "num_comments": 500, "num_awards": 10}
    score = calculate_engagement_score(post)
    assert score > 50


def test_engagement_score_capped_at_100():
    post = {"score": 999999, "upvote_ratio": 1.0, "num_comments": 99999, "num_awards": 999}
    score = calculate_engagement_score(post)
    assert score <= 100


def test_engagement_score_awards_add_bonus():
    post_no_awards  = {"score": 100, "upvote_ratio": 0.9, "num_comments": 10, "num_awards": 0}
    post_with_awards = {"score": 100, "upvote_ratio": 0.9, "num_comments": 10, "num_awards": 5}
    assert calculate_engagement_score(post_with_awards) > calculate_engagement_score(post_no_awards)


def test_comment_velocity_returns_zero_for_no_created_utc():
    post = {"num_comments": 100, "created_utc": 0}
    assert calculate_comment_velocity(post) == 0.0


def test_comment_velocity_positive_for_recent_post():
    import time
    post = {"num_comments": 50, "created_utc": int(time.time()) - 3600}
    velocity = calculate_comment_velocity(post)
    assert velocity > 0