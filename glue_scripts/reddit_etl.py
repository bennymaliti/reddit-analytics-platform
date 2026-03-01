"""
AWS Glue ETL Job — Reddit Analytics Platform
Reads raw Parquet from S3, aggregates daily analytics, writes back to S3.
Schedule: daily at 06:00 UTC via Glue Trigger
"""
import sys
from datetime import datetime, timedelta, timezone
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, LongType, BooleanType

args = getResolvedOptions(sys.argv, ["JOB_NAME", "SOURCE_BUCKET", "OUTPUT_BUCKET"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y/%m/%d")
SOURCE_PATH = f"s3://{args['SOURCE_BUCKET']}/firehose/{yesterday}/"
OUTPUT_BASE = f"s3://{args['OUTPUT_BUCKET']}/aggregated/"

print(f"[ETL] Reading from: {SOURCE_PATH}")

schema = StructType([
    StructField("post_id",      StringType(),  nullable=False),
    StructField("subreddit_id", StringType(),  nullable=True),
    StructField("title",        StringType(),  nullable=True),
    StructField("author_id",    StringType(),  nullable=True),
    StructField("score",        LongType(),    nullable=True),
    StructField("upvote_ratio", DoubleType(),  nullable=True),
    StructField("num_comments", LongType(),    nullable=True),
    StructField("num_awards",   LongType(),    nullable=True),
    StructField("is_nsfw",      BooleanType(), nullable=True),
    StructField("created_utc",  LongType(),    nullable=True),
    StructField("ingested_at",  StringType(),  nullable=True),
])

try:
    raw_df = spark.read.schema(schema).parquet(SOURCE_PATH)
    print(f"[ETL] Loaded {raw_df.count()} records")
except Exception as e:
    print(f"[ETL] WARNING: Could not read source — {e}. Exiting cleanly.")
    job.commit()
    sys.exit(0)

raw_df = raw_df.dropDuplicates(["post_id"])

# Subreddit daily summary
subreddit_summary = raw_df.groupBy("subreddit_id").agg(
    F.count("post_id").alias("post_count"),
    F.avg("score").alias("avg_score"),
    F.avg("upvote_ratio").alias("avg_upvote_ratio"),
    F.avg("num_comments").alias("avg_comments"),
    F.sum("num_awards").alias("total_awards"),
    F.max("score").alias("max_score"),
    F.countDistinct("author_id").alias("unique_authors"),
).withColumn("report_date", F.lit(yesterday.replace("/", "-")))

subreddit_summary.write.mode("overwrite").parquet(
    f"{OUTPUT_BASE}subreddit_daily/date={yesterday.replace('/', '-')}/"
)
print(f"[ETL] Subreddit summary written")

# Top posts by engagement score
top_posts = raw_df.withColumn(
    "engagement_score",
    (F.col("score") * F.col("upvote_ratio") * F.log1p(F.col("num_comments"))).cast(DoubleType())
).orderBy(F.desc("engagement_score")).limit(1000)

top_posts.write.mode("overwrite").parquet(
    f"{OUTPUT_BASE}top_posts_daily/date={yesterday.replace('/', '-')}/"
)
print(f"[ETL] Top posts written")

# Author activity
author_activity = raw_df.groupBy("author_id").agg(
    F.count("post_id").alias("posts_today"),
    F.avg("score").alias("avg_score_today"),
    F.collect_set("subreddit_id").alias("subreddits_active"),
).filter(F.col("author_id") != "[deleted]")

author_activity.write.mode("overwrite").parquet(
    f"{OUTPUT_BASE}author_activity_daily/date={yesterday.replace('/', '-')}/"
)
print(f"[ETL] Author activity written")

print("[ETL] Job complete.")
job.commit()
