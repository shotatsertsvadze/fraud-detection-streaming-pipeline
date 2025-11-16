# Zip the Lambda folder
data "archive_file" "ingest_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/ingest_handler"
  output_path = "${path.module}/../lambdas/ingest_handler.zip"
}

resource "aws_lambda_function" "ingest" {
  function_name = "${local.name_prefix}-ingest"
  role          = aws_iam_role.ingest_lambda_role.arn
  handler       = "app.handler"
  runtime       = "python3.11"
  filename      = data.archive_file.ingest_zip.output_path
  timeout       = 10

  environment {
    variables = {
      STREAM_NAME = aws_kinesis_stream.transactions.name
    }
  }
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "ingest" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_transactions" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /transactions"
  target    = "integrations/${aws_apigatewayv2_integration.ingest.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
