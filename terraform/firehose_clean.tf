resource "aws_kinesis_firehose_delivery_stream" "to_s3_clean" {
  name        = "${local.name_prefix}-to-s3-clean"
  destination = "extended_s3"

  # Source: same Kinesis stream as raw
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.transactions.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.clean.arn
    buffering_interval = 60
    buffering_size     = 5
    compression_format = "GZIP"
    kms_key_arn        = aws_kms_key.data_key.arn

    # 🔹 Lambda transform lives here, inside extended_s3_configuration
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.transform.arn
        }
      }
    }

    prefix              = "year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"
  }
}
