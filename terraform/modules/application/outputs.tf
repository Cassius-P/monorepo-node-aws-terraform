output "load_balancer_dns" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.app.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the application load balancer"
  value       = aws_lb.app.zone_id
}

output "load_balancer_arn" {
  description = "ARN of the application load balancer"
  value       = aws_lb.app.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.app.name
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.ec2.auto_scaling_group_name
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.codepipeline.pipeline_name
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = module.codebuild.project_name
}

output "codedeploy_application_name" {
  description = "Name of the CodeDeploy application"
  value       = module.codedeploy.application_name
}

output "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  value       = module.codepipeline.github_connection_arn
}