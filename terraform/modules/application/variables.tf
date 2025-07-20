variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

# NOTE: instance_type is now configured per application in app_config.instance_type

variable "key_pair_name" {
  description = "AWS Key Pair name"
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

variable "app_config" {
  description = "Application configuration"
  type = object({
    name         = string
    type         = string # "api" or "web"
    port         = number
    path_pattern = string # e.g., "apps/api" or "apps/web"
    node_version = string
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
      min_size                = number
      max_size                = number
      desired_capacity        = number
      scale_up_cpu_threshold  = number
      scale_down_cpu_threshold = number
    })
  })
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener (optional, creates self-signed if not provided)"
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS listener"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}