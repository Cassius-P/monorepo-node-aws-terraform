output "project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.app.name
}

output "project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.app.arn
}

output "artifacts_bucket_name" {
  description = "Name of the S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild_role.arn
}