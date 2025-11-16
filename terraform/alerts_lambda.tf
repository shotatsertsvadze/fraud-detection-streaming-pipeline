# Package the alert handler Lambda
data "archive_file" "alert_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/alert_handler"
  output_path = "${path.module}/../lambdas/alert_handler.zip"
}

# Lambda function for alerts
resource "aws_lambda_function" "alerts" {
  function_name = "${local.name_prefix}-alerts"
  role          = aws_iam_role.alert_lambda_role.arn
  handler       = "app.handler"
  runtime       = "python3.11"
  filename      = data.archive_file.alert_zip.output_path
  timeout       = 10

  environment {
    variables = {
      SNS_TOPIC_ARN         = aws_sns_topic.fraud_alerts.arn
      HIGH_AMOUNT_THRESHOLD = "1000"
      HIGH_RISK_COUNTRIES   = "RU,IR,KP"
    }
  }
}

# Connect Kinesis stream → alerts Lambda
resource "aws_lambda_event_source_mapping" "alerts_from_kinesis" {
  event_source_arn  = aws_kinesis_stream.transactions.arn
  function_name     = aws_lambda_function.alerts.arn
  starting_position = "LATEST"
  batch_size        = 10
  enabled           = true
}
