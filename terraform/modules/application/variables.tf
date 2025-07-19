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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

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
    name              = string
    type              = string # "api" or "web"
    port              = number
    path_pattern      = string # e.g., "apps/api" or "apps/web"
    node_version      = string
    build_command     = string
    start_command     = string
    health_check_path = string
  })
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}