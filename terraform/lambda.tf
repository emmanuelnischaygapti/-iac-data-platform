# Package the Lambda code as a zip (Terraform does this automatically from the source file)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/etl_transform.py"
  output_path = "${path.module}/../lambda/etl_transform.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-etl"
  retention_in_days = 14
}

resource "aws_lambda_function" "etl" {
  function_name    = "${var.project_name}-etl"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "etl_transform.lambda_handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 3008

  # AWS-managed layer: includes pyarrow + pandas, maintained by AWS
  layers = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312:16"]

  environment {
    variables = {
      RAW_BUCKET       = aws_s3_bucket.raw.bucket
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
      RAW_PREFIX       = "nyc-taxi/"
      PROCESSED_PREFIX = "nyc-taxi-clean/"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_logs
  ]
}

# ─── EventBridge schedule ─────────────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "${var.project_name}-etl-schedule"
  description         = "Triggers ETL Lambda on a schedule"
  schedule_expression = var.lambda_schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "etl-lambda"
  arn       = aws_lambda_function.etl.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
