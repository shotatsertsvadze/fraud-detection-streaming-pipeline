resource "aws_sns_topic" "fraud_alerts" {
  name = "${local.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "fraud_alerts_email" {
  topic_arn = aws_sns_topic.fraud_alerts.arn
  protocol  = "email"
  endpoint  = "ichavchavadze67@gmail.com" # replace with your email
}
