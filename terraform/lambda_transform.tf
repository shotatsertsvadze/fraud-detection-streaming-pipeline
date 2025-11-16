# Zip for transform Lambda
data "archive_file" "transform_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/transform_handler"
  output_path = "${path.module}/../lambdas/transform_handler.zip"
}

resource "aws_lambda_function" "transform" {
  function_name = "${local.name_prefix}-transform"
  role          = aws_iam_role.transform_lambda_role.arn
  handler       = "app.handler"
  runtime       = "python3.11"
  filename      = data.archive_file.transform_zip.output_path
  timeout       = 30
}
