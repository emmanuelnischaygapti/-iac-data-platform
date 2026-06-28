locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ─── Raw bucket: landing zone for source data ────────────────────────────────
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-raw-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration { status = "Enabled" }
}

# ─── Processed bucket: cleaned, partitioned output ───────────────────────────
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration { status = "Enabled" }
}
