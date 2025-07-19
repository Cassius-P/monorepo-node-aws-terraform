# Variables for production environment
# These variables are passed through to the root module

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "AWS Key Pair name for EC2 instances"
  type        = string
}

variable "source_repository_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  type        = string
}

variable "default_branch" {
  description = "Default branch to use for the pipeline"
  type        = string
  default     = "main"
}

variable "applications" {
  description = "Map of applications with their configurations"
  type = map(object({
    name              = string
    type              = string # "api" or "web"
    port              = number
    path_pattern      = string # e.g., "apps/api" or "apps/web"
    node_version      = string
    build_command     = string
    start_command     = string
    health_check_path = string
  }))
  default = {
    api = {
      name              = "api"
      type              = "api"
      port              = 3001
      path_pattern      = "apps/api"
      node_version      = "22"
      build_command     = "pnpm run build"
      start_command     = "pnpm run start:prod"
      health_check_path = "/api/v1/health"
    }
    web = {
      name              = "web"
      type              = "web"
      port              = 3000
      path_pattern      = "apps/web"
      node_version      = "22"
      build_command     = "pnpm run build"
      start_command     = "pnpm run start"
      health_check_path = "/"
    }
  }
}