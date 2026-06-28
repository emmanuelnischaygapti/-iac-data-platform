terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state: Terraform stores what it created in this S3 bucket.
  # This must exist BEFORE you run terraform init (see runbook Step 1).
  backend "s3" {
    bucket         = "terraform-state-372382049181"
    key            = "iac-data-platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
    }
  }
}

# Fetch current account info — used to build globally-unique bucket names.
data "aws_caller_identity" "current" {}
