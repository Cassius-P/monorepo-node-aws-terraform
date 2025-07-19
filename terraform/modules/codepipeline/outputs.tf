output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.pipeline.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.pipeline.arn
}

output "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  value       = var.github_connection_arn
}

output "artifacts_bucket_name" {
  description = "Name of the pipeline artifacts S3 bucket"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.arn
}