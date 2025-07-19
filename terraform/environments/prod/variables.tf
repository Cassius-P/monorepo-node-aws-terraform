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

# NOTE: instance_type is now configured per application in the applications variable

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
    name          = string
    type          = string # "api" or "web"
    port          = number
    path_pattern  = string # e.g., "apps/api" or "apps/web"
    node_version  = string
    build_command = string
    start_command = string
    instance_type = string # EC2 instance type per application
    health_check = object({
      path                = string
      interval            = number
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
      matcher             = string
    })
    scaling = object({
      min_size                 = number
      max_size                 = number
      desired_capacity         = number
      scale_up_cpu_threshold   = number
      scale_down_cpu_threshold = number
    })
  }))
  default = {
    api = {
      name          = "api"
      type          = "api"
      port          = 3001
      path_pattern  = "apps/api"
      node_version  = "22"
      build_command = "pnpm run build"
      start_command = "pnpm run start:prod"
      instance_type = "t3.small"
      health_check = {
        path                = "/api/v1/health"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200"
      }
      scaling = {
        min_size                 = 1
        max_size                 = 5
        desired_capacity         = 2
        scale_up_cpu_threshold   = 70
        scale_down_cpu_threshold = 30
      }
    }
    web = {
      name          = "web"
      type          = "web"
      port          = 3000
      path_pattern  = "apps/web"
      node_version  = "22"
      build_command = "pnpm run build"
      start_command = "pnpm run start"
      instance_type = "t3.micro"
      health_check = {
        path                = "/api/health"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200"
      }
      scaling = {
        min_size                 = 1
        max_size                 = 3
        desired_capacity         = 1
        scale_up_cpu_threshold   = 70
        scale_down_cpu_threshold = 30
      }
    }
  }
}