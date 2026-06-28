variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in tags and resource names"
  type        = string
  default     = "iac-data-platform"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "owner" {
  description = "Owner tag value — your name or team name"
  type        = string
  default     = "emmanuel"
}

variable "alert_email" {
  description = "Email address that receives SNS failure alerts"
  type        = string
  # No default — must be set in terraform.tfvars (never hardcode an email in code)
}

variable "lambda_schedule_expression" {
  description = "EventBridge cron expression for Lambda invocation"
  type        = string
  default     = "rate(1 day)"
}
