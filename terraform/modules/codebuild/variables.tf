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
  description = "Source repository URL"
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