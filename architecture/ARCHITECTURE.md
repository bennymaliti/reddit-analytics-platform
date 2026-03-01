# Architecture Reference

## Data Flow

| Step | From | To | Mechanism |
|------|------|----|-----------|
| 1 | EventBridge | Ingestion Lambda | rate(5 min) invoke |
| 2 | Ingestion Lambda | Reddit PRAW API | HTTPS OAuth2 |
| 3 | Ingestion Lambda | Secrets Manager | GetSecretValue |
| 4 | Ingestion Lambda | Kinesis raw-posts | put_records batched |
| 5 | Ingestion Lambda | S3 raw-archive | put_object gzip JSON |
| 6 | Kinesis raw-posts | 5 analytics Lambdas | Event Source Mapping |
| 7 | Kinesis raw-posts | Kinesis Firehose | source stream |
| 8 | Kinesis Firehose | S3 processed/ | Parquet 5min buffer |
| 9 | Analytics Lambdas | Amazon Comprehend | detect_sentiment |
| 10 | Analytics Lambdas | DynamoDB | put_item / update_item |
| 11 | Trending Lambda | SNS | publish viral threshold |
| 12 | S3 processed/ | Glue Crawler | daily 06:00 UTC |
| 13 | Glue Catalog | Athena | SQL query |
| 14 | Clients | API Gateway | HTTPS + JWT |
| 15 | API Gateway | Analytics Lambda | proxy integration |
| 16 | Analytics Lambda | DynamoDB | query / scan |

## DynamoDB Tables

| Table | PK | SK | TTL |
|-------|----|----|-----|
| reddit-raw-posts | post_id | ingested_at | 30 days |
| reddit-sentiment | post_id | analyzed_at | none |
| reddit-trending | topic | window_ts | 7 days |
| reddit-engagement | post_id | scored_at | none |
| reddit-authors | author | profile_date | none |

## Key Design Decisions

**Single Kinesis stream → 5 consumers** — single source of truth, all consumers read the same canonical event, independently scalable via parallelization_factor.

**DynamoDB PAY_PER_REQUEST** — bursty write patterns from ingestion windows make on-demand the right choice over provisioned capacity.

**ARM64 Graviton Lambda** — 20% cost reduction and faster cold starts for Python workloads.

**Secrets Manager over Parameter Store** — automatic rotation support and audit trail via CloudTrail.

## Security Controls

| Control | Implementation |
|---------|---------------|
| Encryption in transit | TLS 1.2+ on all endpoints |
| Encryption at rest | KMS CMK on DynamoDB, S3, Kinesis |
| Authentication | Cognito JWT on all API endpoints |
| Authorisation | IAM least-privilege per Lambda role |
| Secrets | Secrets Manager, never in env vars |
| Network | WAF rate limiting on API Gateway |
| Audit | CloudTrail + X-Ray traces |
