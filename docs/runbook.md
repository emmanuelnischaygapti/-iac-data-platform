# Runbook — IaC Data Platform

## Prerequisites
- Terraform >= 1.5 installed (`terraform version`)
- AWS CLI configured (`aws sts get-caller-identity` returns your account)
- Git configured

---

## Step 1: Create the remote state S3 bucket (one-time, manual)

Terraform stores its state file in S3. This bucket must exist BEFORE you run
`terraform init` because Terraform needs somewhere to write state on init.
This is the only resource created manually — everything else is Terraform-managed.

```bash
aws s3 mb s3://terraform-state-372382049181 --region us-east-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-372382049181 \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket terraform-state-372382049181 \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Why versioning? If Terraform corrupts the state file, you can roll back to a previous version.

---

## Step 2: Create terraform.tfvars

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` — set `alert_email` to your email address.

---

## Step 3: Initialize Terraform

```bash
cd terraform
terraform init
```

This downloads the AWS provider plugin and connects to the remote state backend.
You'll see: `Terraform has been successfully initialized!`

---

## Step 4: Preview changes

```bash
terraform plan
```

Read the output carefully. You should see ~20 resources to be created.
No changes are made at this step.

---

## Step 5: Apply (deploy)

```bash
terraform apply
```

Type `yes` when prompted. Takes ~2-3 minutes.

---

## Step 6: Confirm your SNS subscription

AWS sends a confirmation email to your `alert_email` address.
Open it and click "Confirm subscription" — alerts won't arrive until you do this.

---

## Step 7: Invoke the Lambda manually

```bash
aws lambda invoke \
  --function-name iac-data-platform-etl \
  --payload '{}' \
  response.json

cat response.json
```

Check CloudWatch logs:
```bash
aws logs tail /aws/lambda/iac-data-platform-etl --follow
```

---

## Step 8: Verify processed output

```bash
aws s3 ls s3://iac-data-platform-processed-372382049181/nyc-taxi-clean/
```

---

## Teardown (destroys all resources)

```bash
terraform destroy
```

Note: the remote state S3 bucket is NOT destroyed (it's not managed by this Terraform config).
Delete it manually if needed: `aws s3 rb s3://terraform-state-372382049181 --force`
