output "api_endpoint" { value = aws_apigatewayv2_stage.prod.invoke_url }
output "raw_bucket" { value = aws_s3_bucket.raw.bucket }
output "kinesis_stream" { value = aws_kinesis_stream.transactions.name }
