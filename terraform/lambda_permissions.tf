# Who am I? Needed so we can scope lambda permission to this account
data "aws_caller_identity" "current" {}

# Allow Firehose to invoke the transform Lambda
resource "aws_lambda_permission" "allow_firehose_transform" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transform.function_name
  principal     = "firehose.amazonaws.com"

  # Make sure only our account + this Firehose stream can invoke it
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = aws_kinesis_firehose_delivery_stream.to_s3_clean.arn
}
