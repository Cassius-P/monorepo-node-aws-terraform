output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# Application-specific outputs
output "applications" {
  description = "Application-specific outputs"
  value = {
    for app_name, app in module.applications : app_name => {
      load_balancer_dns        = app.load_balancer_dns
      load_balancer_zone_id    = app.load_balancer_zone_id
      codepipeline_name        = app.codepipeline_name
      codebuild_project_name   = app.codebuild_project_name
      codedeploy_application_name = app.codedeploy_application_name
      auto_scaling_group_name  = app.auto_scaling_group_name
      github_connection_arn    = app.github_connection_arn
    }
  }
}

# Convenient direct access to load balancer DNS names
output "load_balancer_dns" {
  description = "Load balancer DNS names for all applications"
  value = {
    for app_name, app in module.applications : app_name => app.load_balancer_dns
  }
}

# GitHub connection ARNs
output "github_connection_arns" {
  description = "GitHub connection ARNs for all applications"
  value = {
    for app_name, app in module.applications : app_name => app.github_connection_arn
  }
}

# Pipeline names for monitoring
output "pipeline_names" {
  description = "CodePipeline names for all applications"
  value = {
    for app_name, app in module.applications : app_name => app.codepipeline_name
  }
}