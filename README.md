# Infrastructure-as-Code Data Platform

A fully reproducible AWS data platform defined in Terraform, deployed via GitHub Actions CI/CD.

## What this does

| Component | Tool | Purpose |
|-----------|------|---------|
| Infrastructure | Terraform | S3, Lambda, Glue, CloudWatch, SNS — all as code |
| ETL | Python Lambda | Reads raw NYC taxi Parquet → cleans → writes processed Parquet |
| Scheduling | EventBridge | Triggers Lambda daily |
| CI | GitHub Actions | On PR: fmt + validate + plan |
| CD | GitHub Actions | On merge to main: apply |
| Monitoring | CloudWatch | Dashboard + error alarm |
| Alerting | SNS (email) | Notifies on Lambda failure |

## Quick start (after Terraform is installed)

```bash
# 1. Create the remote state bucket first (one-time, manual)
aws s3 mb s3://terraform-state-372382049181 --region us-east-1
aws s3api put-bucket-versioning \
  --bucket terraform-state-372382049181 \
  --versioning-configuration Status=Enabled

# 2. Create your tfvars
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars — add your alert_email

# 3. Deploy
cd terraform
terraform init
terraform plan
terraform apply
```

## Architecture

```
GitHub PR → CI (plan) → Merge → CD (apply) → AWS
                                              ├── S3 raw / processed
                                              ├── Lambda ETL (daily)
                                              ├── Glue Crawler + Database
                                              ├── CloudWatch Dashboard
                                              └── SNS Email Alerts
```

## Folder structure

```
.github/workflows/   CI (terraform_ci.yml) and CD (terraform_cd.yml)
terraform/           All infrastructure as HCL
lambda/              ETL Python function + Dockerfile
docs/                Runbook and architecture notes
```
