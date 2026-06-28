resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

# Email subscription — AWS sends a confirmation email you must click before alerts arrive
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
