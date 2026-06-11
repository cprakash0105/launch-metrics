# LaunchMetrics — Real-time Analytics Platform for SaaS Startups

A serverless, event-driven analytics platform built on AWS that helps early-stage SaaS startups track product usage, customer behavior, and revenue metrics — with a GenAI "Ask Your Data" interface.

## Architecture

```
Client App
    │
    ▼
API Gateway (REST)
    │
    ▼
Lambda (Ingestion) ──► Kinesis Data Streams
                              │
                              ▼
                        Firehose ──► S3 (Raw Layer: JSON)
                                          │
                                          ▼
                                    Glue ETL Job ──► S3 (Curated Layer: Parquet)
                                                          │
                                          ┌───────────────┼───────────────┐
                                          ▼               ▼               ▼
                                       Athena        QuickSight      Bedrock KB
                                    (Ad-hoc SQL)    (Dashboards)    (RAG Queries)
                                                                         │
                                                                         ▼
                                                                   API Gateway
                                                                         │
                                                                         ▼
                                                                   React Frontend
                                                                   ("Ask Your Data")
```

## Tech Stack

| Layer | Service | Purpose |
|-------|---------|---------|
| Ingestion | API Gateway + Lambda | Accept events from client apps |
| Streaming | Kinesis Data Streams + Firehose | Buffer and deliver to S3 |
| Storage | S3 (raw + curated) | Data lake |
| Processing | Glue (PySpark) | Transform JSON → Parquet, partition |
| Analytics | Athena | Serverless SQL queries |
| GenAI | Bedrock + Knowledge Bases | Natural language data querying |
| Infra | Terraform | Everything as code |
| Monitoring | CloudWatch | Logs, metrics, alarms |

## Project Structure

```
LaunchMetrics/
├── terraform/          # All infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── ingestion/
│   │   ├── storage/
│   │   ├── processing/
│   │   └── rag/
├── src/
│   ├── ingestion/      # Lambda: event ingestion
│   ├── transform/      # Glue: ETL scripts
│   └── rag/            # Lambda: Bedrock RAG query handler
├── docs/
│   ├── AWS_Crash_Course.md
│   └── architecture.md
└── README.md
```

## Getting Started

### Prerequisites
- AWS Account with credits
- AWS CLI configured (`aws configure`)
- Terraform installed
- Python 3.11+

### Deploy
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Test Ingestion
```bash
curl -X POST https://<api-gateway-url>/events \
  -H "Content-Type: application/json" \
  -d '{"tenant_id": "startup_1", "event": "page_view", "user_id": "u123", "page": "/pricing", "timestamp": "2025-06-10T10:00:00Z"}'
```

## Multi-Tenancy Strategy

- Tenant isolation via `tenant_id` partition key in S3 path: `s3://bucket/raw/tenant_id=X/date=Y/`
- Athena queries scoped by tenant partition
- IAM policies can restrict access per tenant (future: row-level security)

## Cost Optimization (Startup-Friendly)

- 100% serverless — zero cost when idle
- Kinesis on-demand mode — no shard planning
- Glue jobs run on schedule (not always-on)
- Athena + Parquet + partitioning = minimal scan cost
- Bedrock pay-per-token — no GPU reservations
