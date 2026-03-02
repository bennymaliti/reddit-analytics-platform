"""Unit tests for content classification Lambda"""
import importlib.util
import os

spec = importlib.util.spec_from_file_location(
    "classification_handler",
    os.path.join(os.path.dirname(__file__), "../../src/lambdas/content_classification/handler.py"),
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

classify_post_type = module.classify_post_type
classify_topic = module.classify_topic


def test_classify_text_post():
    post = {"body": "This is a text post", "url": "https://reddit.com/r/test"}
    assert classify_post_type(post) == "text"


def test_classify_image_post():
    post = {"body": "", "url": "https://i.imgur.com/example.jpg"}
    assert classify_post_type(post) == "image"


def test_classify_video_post():
    post = {"body": "", "url": "https://www.youtube.com/watch?v=example"}
    assert classify_post_type(post) == "video"


def test_classify_link_post():
    post = {"body": "", "url": "https://example.com/article"}
    assert classify_post_type(post) == "link"


def test_classify_technology_topic():
    topic = classify_topic("Python machine learning with AWS Lambda", "")
    assert topic == "technology"


def test_classify_finance_topic():
    topic = classify_topic("Bitcoin market investment strategy", "")
    assert topic == "finance"


def test_classify_general_topic_when_no_keywords():
    topic = classify_topic("hello world", "")
    assert topic == "general"
