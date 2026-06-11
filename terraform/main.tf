terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# S3: Data Lake (Raw + Curated)
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-data-lake-${var.environment}"
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    id     = "archive-raw-data"
    status = "Enabled"
    filter { prefix = "raw/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

# ─────────────────────────────────────────────
# Kinesis Data Stream
# ─────────────────────────────────────────────
resource "aws_kinesis_stream" "events" {
  name             = "${var.project_name}-events"
  stream_mode_details { stream_mode = "ON_DEMAND" }
  retention_period = 24
}

# ─────────────────────────────────────────────
# Kinesis Firehose → S3 (Raw Layer)
# ─────────────────────────────────────────────
resource "aws_iam_role" "firehose" {
  name = "${var.project_name}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "firehose_s3" {
  name = "firehose-s3-access"
  role = aws_iam_role.firehose.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetBucketLocation", "s3:ListBucket"]
      Resource = [aws_s3_bucket.data_lake.arn, "${aws_s3_bucket.data_lake.arn}/*"]
    }, {
      Effect   = "Allow"
      Action   = ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"]
      Resource = aws_kinesis_stream.events.arn
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "to_s3" {
  name        = "${var.project_name}-firehose-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.events.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.data_lake.arn
    prefix     = "raw/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/"
    buffering_size     = 5
    buffering_interval = 60
    compression_format = "GZIP"
  }
}

# ─────────────────────────────────────────────
# Lambda: Ingestion (API Gateway → Kinesis)
# ─────────────────────────────────────────────
resource "aws_iam_role" "ingestion_lambda" {
  name = "${var.project_name}-ingestion-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ingestion_lambda" {
  name = "ingestion-lambda-policy"
  role = aws_iam_role.ingestion_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
      Resource = aws_kinesis_stream.events.arn
    }, {
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

data "archive_file" "ingestion_lambda" {
  type        = "zip"
  source_file = "${path.module}/../src/ingestion/handler.py"
  output_path = "${path.module}/../src/ingestion/handler.zip"
}

resource "aws_lambda_function" "ingestion" {
  function_name    = "${var.project_name}-ingestion"
  role             = aws_iam_role.ingestion_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.ingestion_lambda.output_path
  source_code_hash = data.archive_file.ingestion_lambda.output_base64sha256

  environment {
    variables = {
      KINESIS_STREAM_NAME = aws_kinesis_stream.events.name
    }
  }
}

# ─────────────────────────────────────────────
# API Gateway (REST)
# ─────────────────────────────────────────────
resource "aws_apigatewayv2_api" "events" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "ingestion" {
  api_id                 = aws_apigatewayv2_api.events.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingestion.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_events" {
  api_id    = aws_apigatewayv2_api.events.id
  route_key = "POST /events"
  target    = "integrations/${aws_apigatewayv2_integration.ingestion.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.events.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.events.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
# Glue: ETL (Raw JSON → Curated Parquet)
# ─────────────────────────────────────────────
resource "aws_iam_role" "glue" {
  name = "${var.project_name}-glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "glue-s3-access"
  role = aws_iam_role.glue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
      Resource = [aws_s3_bucket.data_lake.arn, "${aws_s3_bucket.data_lake.arn}/*"]
    }]
  })
}

resource "aws_glue_job" "transform" {
  name     = "${var.project_name}-transform"
  role_arn = aws_iam_role.glue.arn
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.data_lake.id}/scripts/transform.py"
    python_version  = "3"
  }
  default_arguments = {
    "--job-language"          = "python"
    "--S3_INPUT_PATH"         = "s3://${aws_s3_bucket.data_lake.id}/raw/"
    "--S3_OUTPUT_PATH"        = "s3://${aws_s3_bucket.data_lake.id}/curated/"
    "--enable-metrics"        = "true"
    "--enable-spark-ui"       = "true"
  }
  max_retries       = 0
  number_of_workers = 2
  worker_type       = "G.1X"
  glue_version      = "4.0"
}

# ─────────────────────────────────────────────
# Glue Data Catalog (for Athena)
# ─────────────────────────────────────────────
resource "aws_glue_catalog_database" "analytics" {
  name = "${var.project_name}_db"
}

# ─────────────────────────────────────────────
# Athena Workgroup
# ─────────────────────────────────────────────
resource "aws_athena_workgroup" "main" {
  name = "${var.project_name}-workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.id}/athena-results/"
    }
  }
}
