terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Local variables
locals {
  project_name = "comptastar"
  environment  = var.environment
  
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Shared across all applications
module "vpc" {
  source = "./modules/vpc"
  
  project_name        = local.project_name
  environment         = local.environment
  availability_zones  = data.aws_availability_zones.available.names
  tags               = local.common_tags
}

# Note: SSM Parameters are managed manually outside of Terraform
# Use scripts/setup-parameters.sh to create parameters based on .env.example files

# Application Modules - One for each application
module "applications" {
  source = "./modules/application"
  
  for_each = var.applications

  project_name             = local.project_name
  environment              = local.environment
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr_block
  public_subnets           = module.vpc.public_subnets
  private_subnets          = module.vpc.private_subnets
  key_pair_name            = var.key_pair_name
  source_repository_url    = var.source_repository_url
  github_connection_arn    = var.github_connection_arn
  default_branch           = var.default_branch
  app_config               = each.value
  ssl_certificate_arn      = var.ssl_certificate_arn
  enable_https             = var.enable_https
  tags                     = local.common_tags

  depends_on = [module.vpc]
}