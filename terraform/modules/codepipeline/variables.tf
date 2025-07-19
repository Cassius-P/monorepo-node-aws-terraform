variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Name of the application"
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

variable "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "codedeploy_application_name" {
  description = "Name of the CodeDeploy application"
  type        = string
}

variable "codedeploy_group_name" {
  description = "Name of the CodeDeploy deployment group"
  type        = string
}

variable "app_config" {
  description = "Application configuration"
  type = object({
    name              = string
    type              = string
    port              = number
    path_pattern      = string
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