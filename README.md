#  Reddit Social Media Analytics Platform
[![CI/CD Pipeline](https://github.com/bennymaliti/reddit-analytics-platform/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/bennymaliti/reddit-analytics-platform/actions/workflows/ci-cd.yml)
[![Python 3.12](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/downloads/release/python-3120/)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.0-7B42BC.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-eu--west--2-FF9900.svg?logo=amazon-aws)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)


## Architecture


> View the interactive diagram: [architecture.html](architecture.html)

The platform is an event-driven serverless pipeline across 7 Lambda microservices:

```
EventBridge → data_ingestion → Kinesis Data Streams
                                        ↓ (fan-out)
              ┌─────────────────────────────────────────┐
              │ sentiment_analysis  → DynamoDB           │
              │ engagement_scoring  → DynamoDB           │
              │ trending_topics     → DynamoDB           │
              │ content_classification → DynamoDB        │
              │ author_profiling    → DynamoDB           │
              └─────────────────────────────────────────┘
                                        ↓
              api_handler ← API Gateway + Cognito JWT
                                        ↓
              Kinesis Firehose → S3 Parquet → Glue → Athena
```




> A production-grade, serverless microservices architecture on AWS for real-time Reddit data ingestion, sentiment analysis, trending topic detection, and engagement scoring.

[![AWS](https://img.shields.io/badge/AWS-Serverless-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)](https://www.terraform.io)
[![Python](https://img.shields.io/badge/Runtime-Python_3.12-3776AB?logo=python)](https://www.python.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Architecture Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                   REDDIT ANALYTICS PLATFORM                     │
│              AWS Serverless Microservices Architecture           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1 — INGESTION                                            │
│  EventBridge (rate 5min) → Ingestion Lambda → Reddit PRAW API  │
│                          → Secrets Manager (credentials)        │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Kinesis Data Stream │
                    │  reddit-raw-posts    │
                    │  (2 shards, 24h)     │
                    └──┬───┬───┬───┬───┬──┘
                       │   │   │   │   │  (parallel fan-out)
              ┌────────┘   │   │   │   └────────┐
              ▼            ▼   ▼   ▼            ▼
         Sentiment    Trending  Engage  Classify  Author
         Analysis     Topics    Score   Content   Profile
              │            │   │   │            │
              └────────────┴───▼───┴────────────┘
                               │
                    ┌──────────▼──────────┐
                    │     DynamoDB        │
                    │     5 Tables        │
                    └─────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │    API Gateway      │
                    │  + Cognito Auth     │
                    └─────────────────────┘
```

## AWS Services

| Service | Purpose |
|---------|---------|
| AWS Lambda (×7) | All microservices — Python 3.12, ARM64 |
| Amazon Kinesis | Real-time event streaming — 2 shards |
| Kinesis Firehose | Buffered S3 Parquet delivery |
| Amazon DynamoDB | Operational store — 5 tables, on-demand |
| Amazon S3 | Data lake — 3 buckets |
| Amazon Comprehend | NLP sentiment + entity extraction |
| Amazon API Gateway | REST API — regional, Cognito auth |
| Amazon Cognito | JWT authentication |
| AWS EventBridge | Cron scheduling |
| AWS Glue | ETL and data catalog |
| Amazon Athena | Ad-hoc SQL on S3 |
| AWS Secrets Manager | Reddit API credentials |
| Amazon CloudWatch | Logs, metrics, dashboards, alarms |
| AWS X-Ray | Distributed tracing |
| AWS KMS | Encryption at rest |
| AWS WAF | API rate limiting and protection |
| Amazon SNS | Alert fan-out |
| Amazon SQS | Dead letter queues |
| Terraform | Infrastructure as Code |

## Microservices

| # | Function | Trigger | Purpose |
|---|----------|---------|---------|
| 1 | data_ingestion | EventBridge 5min | Fetch Reddit posts, publish to Kinesis |
| 2 | sentiment_analysis | Kinesis | Amazon Comprehend NLP scoring |
| 3 | trending_topics | Kinesis | Rolling topic frequency windows |
| 4 | engagement_scoring | Kinesis | Composite engagement score |
| 5 | content_classification | Kinesis | Post type and topic tagging |
| 6 | author_profiling | Kinesis | Author behavioural metrics |
| 7 | api_handler | API Gateway | Unified REST query layer |

## Prerequisites

- AWS CLI v2 configured
- Terraform >= 1.6.0
- Python 3.12
- Reddit API credentials (free at reddit.com/prefs/apps)

## Deployment

### 1. Store Reddit credentials
```bash
aws secretsmanager create-secret \
  --name "reddit-analytics/api-credentials" \
  --secret-string '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "username": "YOUR_USERNAME",
    "password": "YOUR_PASSWORD",
    "user_agent": "reddit-analytics/1.0"
  }'
```

### 2. Package Lambda functions
```bash
chmod +x scripts/package_lambdas.sh
ARTIFACTS_BUCKET=your-bucket ./scripts/package_lambdas.sh
```

### 3. Deploy infrastructure
```bash
chmod +x scripts/deploy.sh
ENVIRONMENT=prod ./scripts/deploy.sh
```

### 4. Destroy infrastructure
```bash
ENVIRONMENT=prod ./scripts/destroy.sh
```

## API Endpoints

Base URL: `https://{api-id}.execute-api.eu-west-2.amazonaws.com/prod`

All endpoints require `Authorization: Bearer {jwt_token}`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /trending | Trending topics by time window |
| GET | /sentiment/{post_id} | Sentiment for a specific post |
| GET | /engagement | Top posts by engagement score |
| GET | /authors/{username} | Author profile and metrics |
| POST | /search | Full-text search across posts |

## Project Structure
```
reddit-analytics-platform/
├── architecture/          # HTML and Markdown architecture diagrams
├── glue_scripts/          # PySpark ETL job
├── scripts/               # Deploy, destroy, package scripts
├── src/
│   ├── layers/common/     # Shared Python dependencies
│   └── lambdas/           # 7 Lambda function handlers
└── terraform/
    ├── modules/           # 8 reusable Terraform modules
    └── environments/      # dev and prod variable files
```

## Security

- KMS CMK encryption on DynamoDB, S3, Kinesis, Secrets Manager
- IAM least-privilege per-function execution roles
- Cognito JWT on all API endpoints
- WAF rate limiting on API Gateway
- Reddit credentials in Secrets Manager only — never in code

## License

MIT License — see [LICENSE](LICENSE)

## Local Development

Requires Docker Desktop running.

### Start local AWS environment
```bash
./scripts/local_dev.sh start
```

### Check resources created
```bash
./scripts/local_dev.sh status
```

### Invoke a Lambda locally
```bash
./scripts/local_dev.sh invoke data_ingestion
./scripts/local_dev.sh invoke sentiment_analysis
```

### Scan a DynamoDB table
```bash
./scripts/local_dev.sh scan reddit-analytics-local-raw-posts
```

### Stop local environment
```bash
./scripts/local_dev.sh stop
```


## Cost Estimate

Estimated monthly AWS cost for this project at low/moderate usage:

| Service | Usage | Est. Monthly Cost |
|---|---|---|
| Lambda | 7 functions × 1,000 invocations/day | ~$0.00 (free tier) |
| Kinesis Data Streams | 1 shard | ~$0.36 |
| DynamoDB | 5 tables, on-demand, ~10K writes/day | ~$0.25 |
| S3 | ~1 GB storage + requests | ~$0.03 |
| API Gateway | ~1,000 requests/day | ~$0.00 (free tier) |
| Amazon Comprehend | ~10K units/day | ~$0.50 |
| CloudWatch | Logs + dashboards | ~$0.50 |
| Kinesis Firehose | ~100MB/day | ~$0.02 |
| **Total** | | **~$1.66/month** |

> Costs are negligible at portfolio/demo scale. Lambda, API Gateway, and DynamoDB all have generous free tiers.
> Estimate generated using [AWS Pricing Calculator](https://calculator.aws).


## API Endpoints

Base URL: `https://k4hf8nzxoi.execute-api.eu-west-2.amazonaws.com/prod`

All endpoints require a Cognito JWT token in the Authorization header.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /health | Service health check |
| GET | /posts | List ingested posts |
| GET | /sentiment | List sentiment analysis results |
| GET | /sentiment/{post_id} | Get sentiment for a specific post |
| GET | /trending | Get trending topics (default: 24h window) |
| GET | /engagement | Get engagement scores |
| GET | /authors | List author profiles |
| GET | /authors/{username} | Get profile for a specific author |
| POST | /search | Search posts by keyword |

### Quick Test

```bash
# 1. Get a token
TOKEN=$(aws cognito-idp initiate-auth   --auth-flow USER_PASSWORD_AUTH   --client-id 18g17sp2pr934o37edkn80ijp   --region eu-west-2   --query "AuthenticationResult.IdToken"   --output text)

BASE="https://k4hf8nzxoi.execute-api.eu-west-2.amazonaws.com/prod"

# 2. Test endpoints
curl -s "$BASE/health"     -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
curl -s "$BASE/trending"   -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
curl -s "$BASE/engagement" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
curl -s "$BASE/sentiment"  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
curl -s "$BASE/authors"    -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```
