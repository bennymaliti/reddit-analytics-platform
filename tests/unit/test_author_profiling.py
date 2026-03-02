"""Unit tests for author profiling Lambda"""
import importlib.util
import os

spec = importlib.util.spec_from_file_location(
    "author_handler",
    os.path.join(os.path.dirname(__file__), "../../src/lambdas/author_profiling/handler.py"),
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

calculate_bot_score = module.calculate_bot_score


def test_bot_score_low_for_normal_user():
    score = calculate_bot_score(post_count=5, avg_score=100, subreddit_count=3)
    assert score < 0.5


def test_bot_score_high_for_suspicious_account():
    score = calculate_bot_score(post_count=500, avg_score=1, subreddit_count=50)
    assert score > 0.5


def test_bot_score_between_0_and_1():
    score = calculate_bot_score(post_count=100, avg_score=50, subreddit_count=10)
    assert 0.0 <= score <= 1.0


def test_bot_score_low_post_count():
    # Low post count, good engagement, single subreddit = not a bot
    score = calculate_bot_score(post_count=2, avg_score=200, subreddit_count=1)
    assert score < 0.3


def test_bot_score_high_volume_low_score():
    # High volume + low scores = suspicious
    score = calculate_bot_score(post_count=200, avg_score=0, subreddit_count=30)
    assert score > 0.5
