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

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (if HTTPS is enabled)"
  value       = var.enable_https ? aws_lb_listener.https[0].arn : null
}

output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate used"
  value       = var.enable_https ? (var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : aws_acm_certificate.alb_cert[0].arn) : null
}

output "load_balancer_urls" {
  description = "Available URLs for the load balancer"
  value = {
    http  = "http://${aws_lb.app.dns_name}"
    https = var.enable_https ? "https://${aws_lb.app.dns_name}" : null
  }
}