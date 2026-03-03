# Contributing Guide

## Branch Workflow
```
main          <- production, protected, auto-deploys to AWS
develop       <- integration branch, all PRs merge here first
feature/*     <- your working branch
```

**Never commit directly to `main` or `develop`.**

## Getting Started

### 1. Clone the repository
```bash
git clone https://github.com/bennymaliti/reddit-analytics-platform.git
cd reddit-analytics-platform
```

### 2. Install development dependencies
```bash
pip install -r requirements-dev.txt
```

### 3. Create a feature branch
```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

---

## Running Tests Locally

### Unit tests
```bash
pytest tests/unit/ -v
```

### Integration tests
```bash
pytest tests/integration/ -v
```

### All tests with coverage
```bash
pytest tests/ -v --cov=src/lambdas --cov-report=term-missing
```

---

## Code Quality

### Format Python code
```bash
black src/lambdas/ --line-length 100
```

### Lint Python code
```bash
flake8 src/lambdas/
```

### Format Terraform code
```bash
cd terraform
terraform fmt -recursive
```

### Validate Terraform
```bash
cd terraform
terraform init -backend=false
terraform validate
```

---

## Making a Pull Request

1. Push your feature branch
```bash
git push origin feature/your-feature-name
```

2. Open a PR on GitHub: `feature/your-feature-name` → `develop`

3. All CI checks must pass before merging:
   - ✅ Python Checks (syntax, Black, Flake8, unit tests)
   - ✅ Integration Tests
   - ✅ Terraform Checks (fmt, validate)
   - ✅ Terraform Plan (posted as PR comment)

4. Merge into `develop`

5. When ready for production, open a PR: `develop` → `main`
   - Terraform Apply runs automatically on merge to `main`

---

## Project Structure
```
reddit-analytics-platform/
├── .github/workflows/     # CI/CD pipeline
├── architecture/          # Architecture diagrams
├── glue_scripts/          # PySpark ETL job
├── scripts/               # Deploy, destroy, package scripts
├── src/
│   ├── layers/common/     # Shared Lambda dependencies
│   └── lambdas/           # 7 Lambda function handlers
│       ├── data_ingestion/
│       ├── sentiment_analysis/
│       ├── trending_topics/
│       ├── engagement_scoring/
│       ├── content_classification/
│       ├── author_profiling/
│       └── api_handler/
├── terraform/
│   ├── modules/           # 8 reusable Terraform modules
│   │   ├── api_gateway/
│   │   ├── dynamodb/
│   │   ├── eventbridge/
│   │   ├── glue/
│   │   ├── iam/
│   │   ├── kinesis/
│   │   ├── lambda/
│   │   └── s3/
│   └── environments/      # dev and prod variable files
├── tests/
│   ├── unit/              # Unit tests per Lambda
│   └── integration/       # Integration tests with moto
├── requirements-dev.txt
└── setup.cfg
```

---

## Environment Variables

Lambda functions require these environment variables (set automatically by Terraform):

| Variable | Description |
|----------|-------------|
| `KINESIS_RAW_STREAM` | Kinesis stream name for raw posts |
| `S3_RAW_BUCKET` | S3 bucket for raw post archive |
| `DYNAMODB_RAW_POSTS` | DynamoDB table for raw posts |
| `DYNAMODB_SENTIMENT` | DynamoDB table for sentiment results |
| `DYNAMODB_TRENDING` | DynamoDB table for trending topics |
| `DYNAMODB_ENGAGEMENT` | DynamoDB table for engagement scores |
| `DYNAMODB_AUTHORS` | DynamoDB table for author profiles |
| `REDDIT_SECRET_NAME` | Secrets Manager secret name |
| `SNS_ALERTS_ARN` | SNS topic ARN for alerts |
| `SNS_TRENDING_ARN` | SNS topic ARN for trending spikes |

---

## Deployment

### Deploy to AWS
```bash
ENVIRONMENT=prod ./scripts/deploy.sh
```

### Destroy infrastructure
```bash
ENVIRONMENT=prod ./scripts/destroy.sh
```

### Store Reddit credentials
```bash
aws secretsmanager create-secret \
  --name "reddit-analytics/api-credentials" \
  --region eu-west-2 \
  --secret-string '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "username": "YOUR_USERNAME",
    "password": "YOUR_PASSWORD",
    "user_agent": "reddit-analytics-platform/1.0"
  }'
```
