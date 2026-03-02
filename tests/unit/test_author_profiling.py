"""Unit tests for author profiling Lambda"""
import pytest
import sys
import os
os.environ.setdefault("AWS_REGION", "eu-west-2")
os.environ.setdefault("AWS_DEFAULT_REGION", "eu-west-2")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../src/lambdas/author_profiling"))

from handler import calculate_bot_score


def test_bot_score_low_for_normal_user():
    score = calculate_bot_score(post_count=5, avg_score=100, subreddit_count=3)
    assert score < 0.5


def test_bot_score_high_for_suspicious_account():
    score = calculate_bot_score(post_count=500, avg_score=1, subreddit_count=50)
    assert score > 0.5


def test_bot_score_between_0_and_1():
    score = calculate_bot_score(post_count=100, avg_score=50, subreddit_count=10)
    assert 0.0 <= score <= 1.0


def test_bot_score_zero_activity():
    score = calculate_bot_score(post_count=0, avg_score=0, subreddit_count=0)
    assert score == 0.0
