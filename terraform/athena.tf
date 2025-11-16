# Results bucket for Athena queries
resource "aws_s3_bucket" "athena_results" {
  bucket = "${local.name_prefix}-athena-results"
}

# Athena workgroup with results output to the bucket above
resource "aws_athena_workgroup" "wg" {
  name = "${local.name_prefix}-wg"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }
}

# Glue/Athena database (logical namespace)
resource "aws_athena_database" "db" {
  name   = "${replace(local.name_prefix, "-", "_")}_db"
  bucket = aws_s3_bucket.athena_results.bucket
}

# Saved query to create external table over the raw bucket with partition projection
resource "aws_athena_named_query" "create_raw_table" {
  name      = "create_raw_table"
  workgroup = aws_athena_workgroup.wg.name
  database  = aws_athena_database.db.name

  query = <<SQL
CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.db.name}.raw_transactions (
  transaction_id string,
  timestamp string,
  amount double,
  currency string,
  merchant string,
  country string,
  card_last4 string,
  channel string,
  features map<string,double>
)
PARTITIONED BY (
  year string,
  month string,
  day string,
  hour string
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://${aws_s3_bucket.raw.bucket}/'
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.year.type'='integer','projection.year.range'='2020,2035',
  'projection.month.type'='integer','projection.month.range'='1,12',
  'projection.day.type'='integer','projection.day.range'='1,31',
  'projection.hour.type'='integer','projection.hour.range'='0,23',
  'storage.location.template'='s3://${aws_s3_bucket.raw.bucket}/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/'
);
SQL
}
