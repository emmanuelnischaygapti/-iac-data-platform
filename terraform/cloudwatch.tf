resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Invocations"
          region  = var.aws_region
          period  = 300
          stat    = "Sum"
          metrics = [["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.etl.function_name]]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Errors"
          region  = var.aws_region
          period  = 300
          stat    = "Sum"
          metrics = [["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.etl.function_name]]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Duration (ms)"
          region  = var.aws_region
          period  = 300
          stat    = "Average"
          metrics = [["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.etl.function_name]]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-error-alarm"
  alarm_description   = "Triggers when ETL Lambda reports errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.etl.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
