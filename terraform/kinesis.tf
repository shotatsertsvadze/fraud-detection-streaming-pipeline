resource "aws_kinesis_stream" "transactions" {
  name             = "${local.name_prefix}-stream"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = aws_kms_key.data_key.arn
}
