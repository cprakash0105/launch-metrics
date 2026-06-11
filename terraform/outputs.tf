output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.events.api_endpoint
}

output "s3_bucket" {
  description = "Data lake S3 bucket name"
  value       = aws_s3_bucket.data_lake.id
}

output "kinesis_stream" {
  description = "Kinesis stream name"
  value       = aws_kinesis_stream.events.name
}

output "glue_job" {
  description = "Glue ETL job name"
  value       = aws_glue_job.transform.name
}

output "athena_workgroup" {
  description = "Athena workgroup name"
  value       = aws_athena_workgroup.main.name
}
