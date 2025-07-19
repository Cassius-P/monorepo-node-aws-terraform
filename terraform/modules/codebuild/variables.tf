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
    name         = string
    type         = string
    port         = number
    path_pattern = string
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

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}