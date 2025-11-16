# Trust policy so Firehose can assume this role
data "aws_iam_policy_document" "firehose_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

# Role used by BOTH Firehose streams (raw + clean)
resource "aws_iam_role" "firehose_role" {
  name               = "${local.name_prefix}-firehose-role"
  assume_role_policy = data.aws_iam_policy_document.firehose_trust.json
}

# Permissions for Firehose: S3, Kinesis, KMS, Lambda invoke
data "aws_iam_policy_document" "firehose_policy" {
  # S3: write to raw AND clean buckets
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.raw.arn,
      "${aws_s3_bucket.raw.arn}/*",
      aws_s3_bucket.clean.arn,
      "${aws_s3_bucket.clean.arn}/*"
    ]
  }

  # Use KMS key for encryption
  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.data_key.arn]
  }

  # Read from Kinesis source stream
  statement {
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords"
    ]
    resources = [aws_kinesis_stream.transactions.arn]
  }

  # Allow Firehose to invoke Lambda for transformations
  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "firehose_inline" {
  name   = "${local.name_prefix}-firehose-policy"
  policy = data.aws_iam_policy_document.firehose_policy.json
}

resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_inline.arn
}

# Firehose delivery: Kinesis -> S3 (RAW)
resource "aws_kinesis_firehose_delivery_stream" "to_s3_raw" {
  name        = "${local.name_prefix}-to-s3-raw"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.transactions.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw.arn
    buffering_interval = 60
    buffering_size     = 5
    compression_format = "GZIP"
    kms_key_arn        = aws_kms_key.data_key.arn

    prefix              = "year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"
  }
}
