# AWS Crash Course for GCP/Azure Engineers

> You already know cloud. This maps what you know to AWS equivalents + the key differences that trip people up.

---

## 1. Core Mental Model Differences

| Concept | GCP | Azure | AWS |
|---------|-----|-------|-----|
| Resource hierarchy | Project → Folder → Org | Subscription → Resource Group → Management Group | Account → OU → Organization |
| Multi-account strategy | Multiple Projects | Multiple Subscriptions | **AWS Organizations + multiple accounts** (this is the AWS way — 1 account per workload/env) |
| Default networking | Global VPC | Regional VNet | **Regional VPC** (you must explicitly peer or use Transit Gateway) |
| IAM model | Project-level roles | RBAC on resource groups | **IAM policies attached to users/roles/groups — very granular** |
| CLI | `gcloud` | `az` | `aws` (+ `sam` for serverless) |
| IaC (native) | Deployment Manager | ARM/Bicep | **CloudFormation** (but everyone uses Terraform) |

---

## 2. Compute

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| VMs | Compute Engine | Virtual Machines | **EC2** | AMIs (images) are region-specific |
| Containers (managed) | Cloud Run | Container Apps | **ECS Fargate** | No cluster to manage, pay per vCPU/sec |
| Kubernetes | GKE | AKS | **EKS** | More setup than GKE, but same K8s underneath |
| Serverless functions | Cloud Functions | Azure Functions | **Lambda** | 15 min max timeout, cold starts matter, layers for deps |
| Batch jobs | Cloud Batch | Azure Batch | **AWS Batch** or **Step Functions + Lambda** |

### Lambda Key Points (you'll use this A LOT):
- Max 15 min execution, 10GB memory, 512MB /tmp storage
- Package deps as **Lambda Layers** or container images
- Triggered by almost anything: API Gateway, S3, SQS, Kinesis, EventBridge, DynamoDB Streams
- **Cold starts**: Python ~200-500ms, Java ~2-5s. Use provisioned concurrency if needed.

---

## 3. Storage

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| Object storage | GCS | Blob Storage | **S3** | Bucket names are globally unique. Versioning, lifecycle rules, storage classes (Standard → IA → Glacier) |
| Block storage | Persistent Disk | Managed Disk | **EBS** | Attached to single EC2, snapshots to S3 |
| File storage | Filestore | Azure Files | **EFS** (Linux) / **FSx** (Windows) | EFS is NFS, auto-scaling |
| Archive | Coldline/Archive | Cool/Archive | **S3 Glacier / Glacier Deep Archive** | Retrieval times: minutes to hours |

### S3 Key Points:
- Everything in AWS revolves around S3. Data lakes, logs, artifacts, static hosting — all S3.
- **Event notifications**: S3 can trigger Lambda, SQS, SNS on object creation/deletion
- **S3 Select / Glacier Select**: Query data in-place without downloading

---

## 4. Databases

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| Managed SQL | Cloud SQL | Azure SQL / Postgres | **RDS** (MySQL, Postgres, SQL Server, Oracle) | Multi-AZ for HA, Read Replicas for scale |
| Managed SQL (serverless, auto-scale) | AlloyDB / Cloud SQL | Azure SQL Serverless | **Aurora Serverless v2** | Scales to zero, PostgreSQL/MySQL compatible |
| NoSQL (document/key-value) | Firestore / Bigtable | Cosmos DB | **DynamoDB** | Single-digit ms latency, pay-per-request or provisioned. **Design for access patterns first** (no flexible queries like Cosmos) |
| In-memory cache | Memorystore | Azure Cache | **ElastiCache** (Redis / Memcached) | |
| Graph | — | Cosmos (Gremlin) | **Neptune** | |

### DynamoDB Key Points (startups love this):
- Schema-less, infinite scale, zero ops
- **Partition key + sort key** design is EVERYTHING. Think about access patterns upfront.
- **DynamoDB Streams** → trigger Lambda on every write (like Firestore triggers)
- **On-demand pricing** = perfect for startups (no capacity planning)

---

## 5. Networking

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| Virtual network | VPC (global) | VNet (regional) | **VPC (regional)** | Subnets are AZ-specific (not regional like GCP) |
| Load balancer | Cloud Load Balancing | Azure LB / App Gateway | **ALB** (L7) / **NLB** (L4) / **CLB** (legacy) | ALB for HTTP, NLB for TCP/gRPC |
| DNS | Cloud DNS | Azure DNS | **Route 53** | Also does domain registration |
| CDN | Cloud CDN | Azure CDN | **CloudFront** | Edge locations worldwide, integrates with S3/ALB |
| API management | Apigee | API Management | **API Gateway** | REST & WebSocket & HTTP APIs. Throttling, auth, caching built-in |
| VPC peering across accounts | Shared VPC | VNet Peering | **VPC Peering** or **Transit Gateway** (hub-spoke) |

### VPC Key Points:
- **Public subnet** = has route to Internet Gateway
- **Private subnet** = no direct internet, uses **NAT Gateway** for outbound
- **Security Groups** (stateful, instance-level) + **NACLs** (stateless, subnet-level)

---

## 6. Messaging & Integration

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| Pub/Sub (fan-out) | Pub/Sub | Service Bus Topics | **SNS** (Simple Notification Service) | Push-based, fan-out to SQS/Lambda/HTTP |
| Message queue | Pub/Sub (pull) | Service Bus Queues | **SQS** | Pull-based, at-least-once delivery, FIFO available |
| Event bus | Eventarc | Event Grid | **EventBridge** | Rule-based routing, schema registry, 90+ AWS sources |
| Streaming | Pub/Sub / Dataflow | Event Hubs | **Kinesis Data Streams** | Shard-based, 24h-365d retention, real-time |
| Orchestration | Cloud Workflows / Composer | Logic Apps / Durable Functions | **Step Functions** | Visual workflows, error handling, retries built-in |

### Key Mental Model:
- **SNS** = "I want to notify multiple subscribers" (fan-out)
- **SQS** = "I want a buffer queue between producer and consumer" (decouple)
- **EventBridge** = "I want event-driven routing with rules" (smart bus)
- **Kinesis** = "I need ordered, high-throughput real-time streaming" (like Kafka-lite)

Common pattern: **SNS → SQS → Lambda** (fan-out + buffer + process)

---

## 7. Data & Analytics

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| Data warehouse | BigQuery | Synapse | **Redshift** (or **Athena** for serverless) | Redshift = provisioned clusters. Athena = serverless SQL on S3 (pay per scan) |
| ETL | Dataflow / Dataproc | Data Factory / Databricks | **Glue** (serverless Spark) / **EMR** (managed Spark/Hadoop) | Glue = no infra, auto-scales. EMR = more control |
| Streaming ETL | Dataflow | Stream Analytics | **Kinesis Data Firehose** (now called Firehose) | Zero-code delivery to S3/Redshift/OpenSearch |
| Data catalog | Data Catalog | Purview | **Glue Data Catalog** | Also serves as Hive metastore for Athena/EMR |
| BI / Dashboards | Looker | Power BI | **QuickSight** | Pay-per-session pricing, SPICE in-memory engine |
| Spark notebooks | Dataproc + Jupyter | Databricks / Synapse | **EMR Studio** / **Glue Notebooks** / **Databricks on AWS** |

### Athena Key Points (you'll use this in the project):
- Serverless SQL directly on S3 files (Parquet, JSON, CSV, ORC)
- No infra, no clusters — just write SQL
- $5 per TB scanned → use **columnar formats (Parquet)** and **partitioning** to save cost
- Uses Glue Data Catalog as the metastore

---

## 8. AI/ML & GenAI

| What you want | GCP | Azure | AWS | Key AWS Difference |
|---------------|-----|-------|-----|-------------------|
| ML platform | Vertex AI | Azure ML | **SageMaker** | Training, inference, MLOps — full lifecycle |
| GenAI / LLMs | Vertex AI (Gemini) | Azure OpenAI | **Bedrock** | Access to Claude, Titan, Llama, Mistral, Cohere — no infra |
| RAG | Vertex AI Search | Azure AI Search + OpenAI | **Bedrock Knowledge Bases** | S3 → auto-chunked → OpenSearch/FAISS → query via API |
| Embeddings | Vertex Embeddings | Azure OpenAI Embeddings | **Titan Embeddings** (via Bedrock) | |
| Vector DB | AlloyDB / Vertex Vector Search | Azure AI Search | **OpenSearch Serverless** / **Aurora pgvector** / **Bedrock KB (managed)** |

### Bedrock Key Points (for your RAG layer):
- Fully managed — no model hosting, no GPUs to manage
- **Knowledge Bases**: Point to S3 → Bedrock chunks, embeds, indexes automatically
- **Agents**: Add tool use / function calling on top of LLMs
- Cheapest way to build GenAI on AWS for startups

---

## 9. Security & IAM

| Concept | GCP | Azure | AWS |
|---------|-----|-------|-----|
| Identity | Google Account / Service Account | Azure AD / Managed Identity | **IAM Users, Roles, Policies** |
| Service-to-service auth | Service Account keys (bad) / Workload Identity | Managed Identity | **IAM Roles** (assumed by services — no keys needed) |
| Secrets | Secret Manager | Key Vault | **Secrets Manager** / **SSM Parameter Store** |
| Encryption keys | Cloud KMS | Azure Key Vault | **KMS** |
| Policies | IAM Roles (allow-only) | RBAC + Azure Policy | **IAM Policies (JSON) — Allow + Deny, very granular** |

### IAM Key Points (biggest difference from GCP):
- **Everything is denied by default** — you must explicitly allow
- Policies are JSON documents with Effect/Action/Resource
- **Roles are assumed** (not assigned like GCP). Lambda assumes a role, EC2 assumes a role, etc.
- **No project-level boundaries** — use separate AWS accounts for isolation (Organizations)

---

## 10. DevOps & Deployment

| What you want | GCP | Azure | AWS |
|---------------|-----|-------|-----|
| CI/CD | Cloud Build | Azure DevOps / GitHub Actions | **CodePipeline + CodeBuild** (or just GitHub Actions) |
| Container registry | Artifact Registry | ACR | **ECR** |
| IaC | Deployment Manager | ARM / Bicep | **CloudFormation** / **CDK** (but use Terraform) |
| Serverless deploy | gcloud deploy | func deploy | **SAM CLI** (`sam build && sam deploy`) |
| Monitoring | Cloud Monitoring | Azure Monitor | **CloudWatch** (logs, metrics, alarms, dashboards) |
| Tracing | Cloud Trace | App Insights | **X-Ray** |

### SAM (Serverless Application Model):
- AWS-specific framework for Lambda + API Gateway + DynamoDB + S3 projects
- `template.yaml` defines infra (like a mini CloudFormation)
- `sam local invoke` — test Lambda locally with Docker
- Great for the project — but we'll use Terraform for more flexibility

---

## 11. Key AWS Concepts That Don't Exist in GCP/Azure

| Concept | What it is | Why it matters |
|---------|-----------|---------------|
| **Availability Zones (AZs)** | Physically separate data centers within a region | You design for multi-AZ — subnets, RDS, etc. are AZ-specific |
| **AWS Organizations + SCPs** | Multi-account governance | "1 account per workload" is best practice (not like GCP projects) |
| **Resource-based policies** | Policies attached TO the resource (S3 bucket policy, SQS policy) | In addition to identity-based IAM policies |
| **VPC Endpoints** | Private connectivity to AWS services without internet | PrivateLink / Gateway Endpoints for S3/DynamoDB |
| **Well-Architected Framework** | 6 pillars: Operational Excellence, Security, Reliability, Performance, Cost, Sustainability | **Know this for the interview** — you'll be asked to apply it |

---

## 12. Services Startups Use Most (Interview Priorities)

Learn these deeply — they cover 80% of startup architectures:

1. **Lambda** — Serverless compute
2. **API Gateway** — HTTP endpoints
3. **S3** — Storage for everything
4. **DynamoDB** — NoSQL database
5. **SQS/SNS/EventBridge** — Messaging & events
6. **Kinesis** — Real-time streaming
7. **ECS Fargate** — Containers without servers
8. **RDS/Aurora** — Managed SQL
9. **CloudFront** — CDN
10. **Bedrock** — GenAI
11. **Athena** — Serverless SQL on S3
12. **Step Functions** — Orchestration
13. **CloudWatch** — Monitoring
14. **IAM** — Security
15. **Terraform/CloudFormation** — IaC

---

## 13. Quick Wins to Get Hands-On

1. Deploy a Lambda via Terraform → trigger it with API Gateway
2. Put an object in S3 → trigger Lambda → write to DynamoDB
3. Send a message to SQS → Lambda processes it
4. Query Parquet files in S3 with Athena
5. Call Bedrock Claude from Lambda (simple prompt)
6. Build a Kinesis → Firehose → S3 pipeline

**These 6 exercises cover the entire LaunchMetrics project foundation.**

---

## 14. Useful CLI Commands to Know

```bash
# Configure
aws configure                          # Set up access key + region

# Lambda
aws lambda invoke --function-name X output.json
aws lambda list-functions

# S3
aws s3 ls
aws s3 cp file.json s3://bucket/path/
aws s3 mb s3://my-bucket-name

# DynamoDB
aws dynamodb put-item --table-name X --item '{"pk":{"S":"123"}}'
aws dynamodb scan --table-name X

# SQS
aws sqs send-message --queue-url X --message-body "hello"

# Kinesis
aws kinesis put-record --stream-name X --data "base64" --partition-key "key1"

# Bedrock
aws bedrock-runtime invoke-model --model-id anthropic.claude-v2 --body '{}' output.json

# CloudWatch
aws logs tail /aws/lambda/my-function --follow
```

---

## Next Step

Start with the **LaunchMetrics project** — it'll force you to use most of these services hands-on. That's 10x more effective than reading docs.
