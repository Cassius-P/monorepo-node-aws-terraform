# Production environment configuration
# This file uses the root main.tf with production-specific variables

terraform {
  required_version = ">= 1.0"
  
  # Uncomment and configure for remote state management
  # backend "s3" {
  #   bucket = "comptastar-terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Use the root module
module "infrastructure" {
  source = "../../"

  # Pass through all variables
  aws_region                = var.aws_region
  environment              = var.environment
  instance_type            = var.instance_type
  key_pair_name            = var.key_pair_name
  source_repository_url    = var.source_repository_url
  github_connection_arn    = var.github_connection_arn
  default_branch           = var.default_branch
  applications             = var.applications
}

# Output important values
output "vpc_id" {
  description = "VPC ID"
  value       = module.infrastructure.vpc_id
}

output "applications" {
  description = "Application-specific outputs"
  value       = module.infrastructure.applications
}

output "load_balancer_dns" {
  description = "Load balancer DNS names for all applications"
  value       = module.infrastructure.load_balancer_dns
}

output "pipeline_names" {
  description = "CodePipeline names for all applications"
  value       = module.infrastructure.pipeline_names
}

output "github_connection_arns" {
  description = "GitHub connection ARNs for all applications"
  value       = module.infrastructure.github_connection_arns
}