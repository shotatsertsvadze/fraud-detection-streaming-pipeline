#######################################################
# Common Lambda trust policy
#######################################################

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#######################################################
# Ingest Lambda (API → Kinesis)
#######################################################

resource "aws_iam_role" "ingest_lambda_role" {
  name               = "${local.name_prefix}-ingest-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "ingest_policy" {
  # Logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  # Put records into Kinesis stream
  statement {
    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords"
    ]
    resources = [
      aws_kinesis_stream.transactions.arn
    ]
  }

  # Use the KMS key that encrypts the Kinesis stream
  statement {
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      aws_kms_key.data_key.arn
    ]
  }
}

resource "aws_iam_policy" "ingest_inline" {
  name   = "${local.name_prefix}-ingest-policy"
  policy = data.aws_iam_policy_document.ingest_policy.json
}

resource "aws_iam_role_policy_attachment" "ingest_attach" {
  role       = aws_iam_role.ingest_lambda_role.name
  policy_arn = aws_iam_policy.ingest_inline.arn
}

#######################################################
# Transform Lambda (Firehose CLEAN → Enrich)
#######################################################

resource "aws_iam_role" "transform_lambda_role" {
  name               = "${local.name_prefix}-transform-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "transform_policy" {
  # Logs only (Firehose handles Kinesis + S3 itself)
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "transform_inline" {
  name   = "${local.name_prefix}-transform-policy"
  policy = data.aws_iam_policy_document.transform_policy.json
}

resource "aws_iam_role_policy_attachment" "transform_attach" {
  role       = aws_iam_role.transform_lambda_role.name
  policy_arn = aws_iam_policy.transform_inline.arn
}

#######################################################
# Alerts Lambda (Kinesis → SNS)
#######################################################

resource "aws_iam_role" "alert_lambda_role" {
  name               = "${local.name_prefix}-alert-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "alert_policy" {
  # Logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  # Publish alerts to SNS topic
  statement {
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.fraud_alerts.arn
    ]
  }

  # Read from Kinesis stream (for event source mapping)
  statement {
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListStreams",
      "kinesis:ListShards"
    ]
    resources = [
      aws_kinesis_stream.transactions.arn
    ]
  }

  # Decrypt Kinesis records encrypted with this KMS key
  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]
    resources = [
      aws_kms_key.data_key.arn
    ]
  }
}

resource "aws_iam_policy" "alert_inline" {
  name   = "${local.name_prefix}-alert-policy"
  policy = data.aws_iam_policy_document.alert_policy.json
}

resource "aws_iam_role_policy_attachment" "alert_attach" {
  role       = aws_iam_role.alert_lambda_role.name
  policy_arn = aws_iam_policy.alert_inline.arn
}
