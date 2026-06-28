output "raw_bucket_name" {
  description = "Name of the raw S3 bucket"
  value       = aws_s3_bucket.raw.bucket
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = aws_s3_bucket.processed.bucket
}

output "lambda_function_name" {
  description = "Name of the ETL Lambda function"
  value       = aws_lambda_function.etl.function_name
}

output "lambda_function_arn" {
  description = "ARN of the ETL Lambda function"
  value       = aws_lambda_function.etl.arn
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.main.name
}

output "cloudwatch_dashboard_url" {
  description = "Direct URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS alert topic"
  value       = aws_sns_topic.alerts.arn
}
