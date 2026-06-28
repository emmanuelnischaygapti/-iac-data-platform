# Infrastructure-as-Code Data Platform

A production-grade AWS data platform built entirely in code — no console clicking, no manual steps, fully reproducible from a single `terraform apply`.

![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20S3%20%7C%20Glue%20%7C%20CloudWatch-FF9900?logo=amazonaws)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python)
![Docker](https://img.shields.io/badge/Docker-Lambda%20Runtime-2496ED?logo=docker)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions)

---

## Business Problem

A SaaS company's data platform was built by clicking through the AWS console — no one wrote down what was created, and when a junior engineer accidentally deleted an S3 bucket, it took three days to figure out what settings it had. There was no CI/CD, so every pipeline change was deployed manually. Failures were discovered from angry Slack messages, not monitoring.

**This project solves all three problems:**
- Infrastructure defined in Terraform — version-controlled, reviewable, reproducible
- GitHub Actions CI/CD — every change goes through PR review and automated validation before deployment
- CloudWatch monitoring + SNS alerts — failures detected within minutes, not hours

---

## Architecture

```
Developer pushes to feature branch
            │
            ▼
    GitHub Actions CI
    ┌─────────────────────────────┐
    │  terraform fmt --check      │
    │  terraform validate         │
    │  terraform plan             │ ◄── posts output as PR comment
    └─────────────────────────────┘
            │
            ▼ PR approved + merged to main
    GitHub Actions CD
    ┌─────────────────────────────┐
    │  terraform apply            │ ◄── auto-deploys approved changes
    └─────────────────────────────┘
            │
            ▼
    AWS Infrastructure
    ┌──────────────────────────────────────────────┐
    │                                              │
    │  S3: raw bucket          S3: processed bucket│
    │  └── nyc-taxi/           └── nyc-taxi-clean/ │
    │         │                        ▲           │
    │         │    Lambda ETL          │           │
    │         └──► (daily schedule) ──┘           │
    │              reads → cleans → writes         │
    │                                              │
    │  Glue Database + Crawler (Athena-queryable)  │
    │                                              │
    │  CloudWatch Dashboard + Alarm                │
    │         │                                    │
    │         ▼                                    │
    │  SNS Email Alert on Lambda failure           │
    │                                              │
    │  IAM: least-privilege roles per service      │
    │  Terraform state: remote S3 backend          │
    │                                              │
    └──────────────────────────────────────────────┘
```

---

## Technology Stack

| Layer | Tool | Why |
|-------|------|-----|
| Infrastructure as Code | Terraform 1.9 | Declarative, cloud-agnostic, industry standard |
| Compute | AWS Lambda (Python 3.12) | Serverless, zero idle cost, fits Free Tier |
| Storage | AWS S3 (raw + processed) | Infinitely scalable, versioned, encrypted |
| Cataloging | AWS Glue Crawler + Database | Schema-on-read, Athena-queryable |
| Scheduling | AWS EventBridge | Serverless cron, triggers Lambda daily |
| Monitoring | CloudWatch Dashboard + Alarm | Lambda health visibility |
| Alerting | AWS SNS (email) | Failure notification within 5 minutes |
| CI/CD | GitHub Actions | Native to GitHub, YAML-based, free tier |
| Containerisation | Docker | Reproducible Lambda build environment |
| Dataset | NYC Yellow Taxi (Jan 2023) | 3M rows, publicly available Parquet |

---

## Project Structure

```
iac-data-platform/
├── .github/
│   └── workflows/
│       ├── terraform_ci.yml     # PR: fmt + validate + plan + PR comment
│       └── terraform_cd.yml     # merge to main: apply
├── terraform/
│   ├── main.tf                  # provider + S3 remote state backend
│   ├── variables.tf             # typed + validated input variables
│   ├── outputs.tf               # bucket names, ARNs, dashboard URL
│   ├── s3.tf                    # raw + processed S3 buckets
│   ├── iam.tf                   # least-privilege roles for Lambda + Glue
│   ├── glue.tf                  # Glue database + crawler
│   ├── lambda.tf                # Lambda function + EventBridge schedule
│   ├── cloudwatch.tf            # dashboard + error alarm
│   ├── sns.tf                   # SNS topic + email subscription
│   └── terraform.tfvars.example # safe-to-commit variable template
├── lambda/
│   ├── etl_transform.py         # ETL logic: filter → derive columns → write Parquet
│   ├── requirements.txt         # pyarrow
│   └── Dockerfile               # AWS Lambda Python base image
├── docs/
│   └── runbook.md               # step-by-step setup and teardown guide
└── README.md
```

---

## ETL Pipeline

The Lambda function processes NYC Yellow Taxi trip data:

| Step | Detail |
|------|--------|
| Source | `s3://raw-bucket/nyc-taxi/yellow_tripdata_2023-01.parquet` |
| Transformations | Select relevant columns, filter trips where `distance > 0` and `total_amount > 0`, add `processed_at` timestamp |
| Output | `s3://processed-bucket/nyc-taxi-clean/yellow_tripdata_2023-01.parquet` |
| Format | Snappy-compressed Parquet |
| Scale | 2,998,642 rows processed per run |
| Schedule | Daily via EventBridge (`rate(1 day)`) |

---

## Security

- All S3 buckets: `block_public_acls = true`, `block_public_policy = true` — zero public exposure
- Lambda role: can only read from raw S3 and write to processed S3 — nothing else
- Glue role: can only read from raw S3 and write to Glue catalog — nothing else
- Terraform state bucket: versioning enabled, server-side encryption enabled
- GitHub Actions: AWS credentials via OIDC — no long-lived access keys stored anywhere
- All resources tagged: `Project`, `Environment`, `Owner`, `ManagedBy`

---

## Quick Start

### Prerequisites
- Terraform >= 1.5 (`terraform version`)
- AWS CLI configured (`aws sts get-caller-identity`)
- Git

### Deploy from scratch

```bash
# Step 1 — Create the remote state bucket (one-time, manual)
aws s3 mb s3://terraform-state-<YOUR_ACCOUNT_ID> --region us-east-1
aws s3api put-bucket-versioning \
  --bucket terraform-state-<YOUR_ACCOUNT_ID> \
  --versioning-configuration Status=Enabled

# Step 2 — Configure variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars — set alert_email

# Step 3 — Deploy
cd terraform
terraform init
terraform plan    # review what will be created
terraform apply   # deploy (~2 minutes)

# Step 4 — Seed raw data
aws s3 cp <path-to-yellow_tripdata_2023-01.parquet> \
  s3://iac-data-platform-raw-<ACCOUNT_ID>/nyc-taxi/yellow_tripdata_2023-01.parquet

# Step 5 — Invoke Lambda manually
aws lambda invoke --function-name iac-data-platform-etl \
  --payload '{}' response.json && cat response.json
```

### Teardown

```bash
terraform destroy
```

Everything Terraform created is destroyed. The remote state bucket is preserved (delete manually if needed).

---

## CI/CD Workflow

### On Pull Request
1. `terraform fmt --check` — fails if code isn't formatted
2. `terraform validate` — catches syntax errors
3. `terraform plan` — shows exactly what will change
4. Plan output posted as a PR comment — reviewer sees infrastructure changes before approving

### On Merge to Main
1. `terraform apply --auto-approve` — deploys the approved changes automatically

No human manually runs `terraform apply` in production. Every infrastructure change is reviewed as code.

---

## Monitoring

**CloudWatch Dashboard** — [open dashboard](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=iac-data-platform-health)

| Widget | Metric | Period |
|--------|--------|--------|
| Lambda Invocations | Count of executions | 5 min |
| Lambda Errors | Count of failures | 5 min |
| Lambda Duration | Average execution time (ms) | 5 min |

**Alerting:** CloudWatch alarm triggers SNS email within 5 minutes if Lambda error count ≥ 1.

---

## Key Design Decisions

**Why Terraform over CloudFormation?**
Cloud-agnostic, cleaner HCL syntax, larger ecosystem, and the same skills transfer across AWS/GCP/Azure.

**Why Lambda over Glue for ETL?**
Lambda has zero idle cost and starts instantly. For this dataset size (3M rows, ~100MB), Lambda with 3GB RAM handles it comfortably. If the dataset grows beyond Lambda's 15-minute timeout, swapping to Glue is a one-file Terraform change.

**Why remote state in S3?**
Local state files cause conflicts when multiple engineers or CI/CD systems run Terraform simultaneously. S3 remote state with versioning is the production standard — one source of truth, rollback capability if state is corrupted.

**Why OIDC instead of access keys for GitHub Actions?**
Long-lived AWS access keys stored as secrets are a security risk — if the secret leaks, the attacker has persistent access. OIDC issues short-lived credentials per workflow run that expire automatically.

---

## Cost

Designed for AWS Free Tier. Estimated monthly cost for active development:

| Service | Free Tier | Estimated Usage | Cost |
|---------|-----------|-----------------|------|
| Lambda | 1M requests, 400K GB-seconds | ~30 invocations/month | $0.00 |
| S3 | 5GB storage | ~200MB | $0.00 |
| CloudWatch | 10 dashboards, 10 alarms | 1 dashboard, 1 alarm | $0.00 |
| SNS | 1M notifications | Minimal | $0.00 |
| Glue Crawler | — | ~$0.01/run | ~$0.30/month |

**Total: < $0.30/month**

---

## Future Improvements

- Add `checkov` or `tfsec` to CI pipeline for IaC security scanning
- Use Terraform modules to make resources reusable across environments (dev/staging/prod)
- Add Terraform workspaces for multi-environment management
- Migrate ETL to AWS Glue for datasets exceeding Lambda's 15-minute timeout
- Add data quality checks with Great Expectations before writing to processed S3
- Enable Athena querying on the Glue catalog with sample queries in the runbook

---

## Author

**Emmanuel Nischay**
[GitHub](https://github.com/emmanuelnischaygapti)
